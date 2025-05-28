{ ehtml.pas atualizado completo com suporte a data-on (load, every Ns, revealed) e todas as implementações anteriores }

unit ehtml;

{$mode objfpc}{$H+}

interface

uses
  JS, Web, Classes, SysUtils;

procedure InitEHTML;
procedure AddHandler(const Name: string; Handler: TProcedureRef);

implementation

var
  HandlerMap: TJSMap;

procedure AddHandler(const Name: string; Handler: TProcedureRef);
begin
  HandlerMap.set(Name, Handler);
end;

function FindTargetElement(el: TJSElement): TJSElement;
var
  targetSel: string;
begin
  Result := el;
  targetSel := el.getAttribute('data-target');

  if targetSel = '' then
    Exit;

  if targetSel = 'this' then
    Exit(el)
  else if targetSel.StartsWith('closest ') then
    Result := el.closest(Copy(targetSel, 9, Length(targetSel)))
  else if targetSel.StartsWith('find ') then
    Result := el.querySelector(Copy(targetSel, 6, Length(targetSel)))
  else if targetSel = 'next' then
    Result := TJSElement(el.nextElementSibling)
  else if targetSel = 'previous' then
    Result := TJSElement(el.previousElementSibling);
end;

procedure ExecuteElementAction(el: TJSElement);
var
  url, verb, confirmMsg, headersStr: string;
  targetEl: TJSElement;
  xhr: TJSXMLHttpRequest;
  handlerName: string;
  includeSel, indicatorSel, paramsStr: string;
  bodyData: string = '';
  headers: TJSObject;
  headerPairs: TJSArray;
  i: Integer;
  json: String;
begin
  confirmMsg := el.getAttribute('data-confirm');
  if (confirmMsg <> '') and not window.confirm(confirmMsg) then
    Exit;

  handlerName := el.getAttribute('data-handler');
  if (handlerName <> '') and Assigned(HandlerMap.get(handlerName)) then
    TProcedureRef(HandlerMap.get(handlerName))();

  url := el.getAttribute('data-get');
  verb := 'GET';
  if url = '' then
  begin
    url := el.getAttribute('data-post');
    verb := 'POST';
  end;
  if url = '' then
  begin
    url := el.getAttribute('data-put');
    verb := 'PUT';
  end;
  if url = '' then
  begin
    url := el.getAttribute('data-delete');
    verb := 'DELETE';
  end;
  if url = '' then
  begin
    url := el.getAttribute('data-patch');
    verb := 'PATCH';
  end;

  if url = '' then Exit;

  targetEl := FindTargetElement(el);
  if not Assigned(targetEl) then
    targetEl := el;

  // disable element
  if el.hasAttribute('data-disable') then
    el['disabled'] := True;

  // indicator
  indicatorSel := el.getAttribute('data-indicator');
  if indicatorSel <> '' then
    TJSElement(document.querySelector(indicatorSel)).style.setProperty('display', 'inline');

  // headers
  headers := TJSObject.new;
  headersStr := el.getAttribute('data-headers');
  if headersStr <> '' then
  begin
    try
      headers := TJSJSON.parse(headersStr);
    except
      console.warn('Invalid data-headers JSON');
    end;
  end;

  // include
  includeSel := el.getAttribute('data-include');
  if includeSel <> '' then
    url += IncludeDataFromSelector(includeSel);

  // vals
  json := el.getAttribute('data-vals');
  if json <> '' then
    bodyData := json;

  // params (query string)
  paramsStr := el.getAttribute('data-params');
  if paramsStr <> '' then
  begin
    if Pos('?', url) = 0 then
      url += '?' + paramsStr
    else
      url += '&' + paramsStr;
  end;

  xhr := newXMLHttpRequest;
  xhr.open(verb, url, true);

  for i := 0 to JSKeys(headers).length - 1 do
    xhr.setRequestHeader(JSKeys(headers)[i], headers[JSKeys(headers)[i]]);

  xhr.onreadystatechange := procedure
  begin
    if xhr.readyState = 4 then
    begin
      if indicatorSel <> '' then
        TJSElement(document.querySelector(indicatorSel)).style.setProperty('display', 'none');

      if xhr.status >= 200 then
        targetEl.innerHTML := xhr.responseText;
    end;
  end;

  if (verb = 'POST') or (verb = 'PUT') or (verb = 'PATCH') then
    xhr.send(bodyData)
  else
    xhr.send;
end;

function IncludeDataFromSelector(sel: string): string;
var
  formEl: TJSHTMLFormElement;
begin
  Result := '';
  formEl := TJSHTMLFormElement(document.querySelector(sel));
  if Assigned(formEl) then
    Result := '&' + FormDataToQueryString(formEl);
end;

function FormDataToQueryString(form: TJSHTMLFormElement): string;
var
  formData: TJSFormData;
  entries: TJSIterator;
  pair: TJSArray;
  resultStr: string = '';
begin
  formData := new(TJSFormData, form);
  entries := formData.entries();
  while not entries.done do
  begin
    pair := TJSArray(entries.next().value);
    if resultStr <> '' then
      resultStr += '&';
    resultStr += encodeURIComponent(pair[0]) + '=' + encodeURIComponent(pair[1]);
  end;
  Result := resultStr;
end;

procedure SetupTriggers;
var
  events: array[0..5] of string = ('click', 'change', 'mouseover', 'submit', 'dblclick', 'input');
  ev: string;
  elList: TJSNodeList;
  i: Integer;
  el: TJSElement;
begin
  for ev in events do
  begin
    elList := document.querySelectorAll('[data-trigger="' + ev + '"]');
    for i := 0 to elList.length - 1 do
    begin
      el := TJSElement(elList[i]);
      el.addEventListener(ev, procedure(e: TJSEvent)
      begin
        ExecuteElementAction(el);
      end);
    end;
  end;
end;

procedure SetupDataOnTriggers;
var
  elements: TJSNodeList;
  i: Integer;
  el: TJSElement;
  onValue: String;
  seconds: Integer;
begin
  elements := document.querySelectorAll('[data-on]');
  for i := 0 to elements.length - 1 do
  begin
    el := TJSElement(elements[i]);
    onValue := el.getAttribute('data-on');

    if onValue = 'load' then
    begin
      ExecuteElementAction(el);
    end
    else if onValue.startsWith('every ') then
    begin
      try
        seconds := StrToInt(Copy(onValue, 7, Length(onValue) - 7 - 1));
        window.setInterval(
          procedure
          begin
            ExecuteElementAction(el);
          end, seconds * 1000
        );
      except
        console.warn('Invalid interval in data-on: "' + onValue + '"');
      end;
    end
    else if onValue = 'revealed' then
    begin
      var observer := new(JSIntersectionObserver, procedure(entries, observer)
        var j: Integer;
        begin
          for j := 0 to entries.length - 1 do
          begin
            var entry := entries[j];
            if Boolean(entry.isIntersecting) then
            begin
              ExecuteElementAction(TJSElement(entry.target));
              observer.unobserve(entry.target);
            end;
          end;
        end);
      observer.observe(el);
    end;
  end;
end;

procedure InitEHTML;
begin
  HandlerMap := TJSMap.new;
  SetupTriggers;
  SetupDataOnTriggers;
end;

end.
