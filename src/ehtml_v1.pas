unit ehtml;

{$mode objfpc}{$H+}

interface

uses
  JS, Web, Classes, SysUtils;

type
  TProcedureRef = reference to procedure;
  TStringArray = array of string;

procedure InitEHTML;
procedure AddHandler(const Name: string; Handler: TProcedureRef);

implementation

var
  HandlerMap: TJSObject;

function ConvertJsonToUrlParams(jsonStr: String): String;
var
  obj: TJSObject;
  keys: TJSStringDynArray;
  i: Integer;
  key, value: String;
  resultStr: String;
begin
  resultStr := '';
  try
    obj := TJSJSON.parseObject(jsonStr);
    keys := TJSObject.keys(obj);
    
    for i := 0 to Length(keys) - 1 do
    begin
      key := String(keys[i]);
      value := String(obj[key]);
      if resultStr <> '' then
        resultStr += '&';
      resultStr += encodeURIComponent(key) + '=' + encodeURIComponent(value);
    end;
  except
    WriteLn('EHTML: Failed to convert JSON to URL params');
  end;
  
  Result := resultStr;
end;

function FormDataToQueryString(form: TJSHTMLFormElement): string;
var
  formData: TJSFormData;
  params: TJSURLSearchParams;
begin
  formData := TJSFormData.new(form);
  params := TJSURLSearchParams.new;
  
  asm
    for (const pair of formData.entries()) {
      params.append(pair[0], pair[1]);
    }
  end;
  
  Result := params.toString();
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

procedure AddHandler(const Name: string; Handler: TProcedureRef);
begin
  HandlerMap[Name] := Handler;
end;

function FindTargetElement(el: TJSElement; customTarget: String = ''): TJSElement;
var
  targetSel: string;
  current: TJSElement;
  selector: String;
begin
  Result := el;
  
  if customTarget <> '' then
    targetSel := customTarget
  else
    targetSel := el.getAttribute('data-target');

  if targetSel = '' then
    Exit;

  try
    if targetSel = 'this' then
      Exit(el)
    else if targetSel.StartsWith('closest ') then
    begin
      selector := Copy(targetSel, 9, Length(targetSel));
      current := el;
      while Assigned(current) and (current <> document.body) do
      begin
        if current.matches(selector) then
          Exit(current);
        current := TJSElement(current.parentElement);
      end;
      Exit(el);
    end
    else if targetSel.StartsWith('find ') then
      Exit(el.querySelector(Copy(targetSel, 6, Length(targetSel))))
    else if targetSel = 'next' then
      Exit(TJSElement(el.nextElementSibling))
    else if targetSel = 'previous' then
      Exit(TJSElement(el.previousElementSibling))
    else
      Exit(document.querySelector(targetSel));
  except
    WriteLn('EHTML: Invalid target selector: ' + targetSel);
    Exit(el);
  end;
end;

procedure HandleSwap(targetEl: TJSElement; response: String; swapType: String);
begin
  case swapType of
    'innerHTML': targetEl.innerHTML := response;
    'outerHTML': targetEl.outerHTML := response;
    'beforebegin': targetEl.insertAdjacentHTML('beforebegin', response);
    'afterbegin': targetEl.insertAdjacentHTML('afterbegin', response);
    'beforeend': targetEl.insertAdjacentHTML('beforeend', response);
    'afterend': targetEl.insertAdjacentHTML('afterend', response);
    'delete': if swapType = 'delete' then targetEl.remove();
    'none': ; // No operation
    else targetEl.innerHTML := response; // default
  end;
end;

procedure ExecuteElementAction(el: TJSElement);
var
  url, verb, confirmMsg, headersStr: string;
  targetEl, errorTarget: TJSElement;
  indicatorEl: TJSHTMLElement;
  xhr: TJSXMLHttpRequest;
  handlerName, includeSel, indicatorSel, paramsStr, swapType: string;
  bodyData: string;
  headers: TJSObject;
  i: Integer;
  json: String;
  handler: TProcedureRef;
  headerKeys: TJSArray; // Alterado para TJSArray
  key, value: String;
begin
  confirmMsg := el.getAttribute('data-confirm');
  if (confirmMsg <> '') and not window.confirm(confirmMsg) then
    Exit;

  handlerName := el.getAttribute('data-handler');
  if (handlerName <> '') and (HandlerMap.hasOwnProperty(handlerName)) then
  begin
    handler := TProcedureRef(HandlerMap[handlerName]);
    if Assigned(handler) then
      handler();
  end;

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

  swapType := el.getAttribute('data-swap');
  if swapType = '' then swapType := 'innerHTML';

  if el.hasAttribute('data-disable') then
    el['disabled'] := 'true';

  indicatorSel := el.getAttribute('data-indicator');
  if indicatorSel <> '' then
  begin
    indicatorEl := TJSHTMLElement(document.querySelector(indicatorSel));
    if Assigned(indicatorEl) then
    begin
      indicatorEl.classList.add('ehtml-indicator');
      indicatorEl.style.setProperty('display', 'inline');
    end;
  end;

  headers := TJSObject.new;
  headersStr := el.getAttribute('data-headers');
  if headersStr <> '' then
  begin
    try
      headers := TJSJSON.parseObject(headersStr);
    except
      WriteLn('EHTML: Invalid data-headers JSON');
    end;
  end;

  includeSel := el.getAttribute('data-include');
  if includeSel <> '' then
    url += IncludeDataFromSelector(includeSel);

  json := el.getAttribute('data-vals');
  bodyData := '';
  if json <> '' then
  begin
    try
      if (verb = 'GET') or (verb = 'DELETE') then
      begin
        url += '?' + ConvertJsonToUrlParams(json);
      end
      else
      begin
        bodyData := json;
      end;
    except
      WriteLn('EHTML: Invalid JSON in data-vals');
    end;
  end;

  paramsStr := el.getAttribute('data-params');
  if paramsStr <> '' then
  begin
    // if Pos('?', url) = 0 then
    //   url += '?' + paramsStr
    // else
    //   url += '&' + paramsStr;
  end;

  xhr := TJSXMLHttpRequest.new;
  xhr.open(verb, url, true);

  // Configurar headers - Versão corrigida
  // if headersStr <> '' then
  // begin
  //   asm
  //     var keys = Object.keys(headers);
  //     for (var i = 0; i < keys.length; i++) {
  //       var key = keys[i];
  //       xhr.setRequestHeader(key, headers[key]);
  //     }
  //   end;
  // end;

  // Configurar content-type para JSON se necessário
  if (bodyData <> '') and ( (verb = 'POST') or (verb = 'PUT') or (verb = 'PATCH') ) then
    xhr.setRequestHeader('Content-Type', 'application/json');

  xhr.onreadystatechange := procedure
  begin
    if xhr.readyState = 4 then
    begin
      if indicatorSel <> '' then
      begin
        indicatorEl := TJSHTMLElement(document.querySelector(indicatorSel));
        if Assigned(indicatorEl) then
        begin
          indicatorEl.classList.remove('ehtml-indicator');
          indicatorEl.style.setProperty('display', 'none');
        end;
      end;

      if (xhr.status >= 200) and (xhr.status < 400) then
      begin
        HandleSwap(targetEl, xhr.responseText, swapType);
      end
      else if el.hasAttribute('data-error-target') then
      begin
        errorTarget := FindTargetElement(el, el.getAttribute('data-error-target'));
        if Assigned(errorTarget) then
        begin
          if el.hasAttribute('data-error-swap') then
            HandleSwap(errorTarget, xhr.responseText, el.getAttribute('data-error-swap'))
          else
            HandleSwap(errorTarget, xhr.responseText, 'innerHTML');
        end;
      end;
    end;
  end;

  if el.hasAttribute('data-push-url') then
  begin
    if el.getAttribute('data-push-url') = 'true' then
      window.history.pushState(null, '', url)
    else
      window.history.pushState(null, '', el.getAttribute('data-push-url'));
  end;

  if (verb = 'POST') or (verb = 'PUT') or (verb = 'PATCH') then
    xhr.send(bodyData)
  else
    xhr.send();
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
      asm
        el.addEventListener(ev, function(e) {
          this.ExecuteElementAction(el);
        }.bind(this));
      end;
    end;
  end;
end;

procedure SetupDataOnTriggers;
var
  elements: TJSNodeList;
  i: Integer;
  el: TJSElement;
  onValue, eventName, eventFilter: String;
  seconds: Integer;
  eventParts: TJSStringDynArray;
begin
  elements := document.querySelectorAll('[data-on]');
  for i := 0 to elements.length - 1 do
  begin
    el := TJSElement(elements[i]);
    onValue := el.getAttribute('data-on');
    eventParts := TJSString(onValue).split(' from:');
    eventName := string(eventParts[0]);
    
    if Length(eventParts) > 1 then
      eventFilter := string(eventParts[1]);

    if eventName = 'load' then
    begin
      ExecuteElementAction(el);
    end
    else if TJSString(eventName).startsWith('every ') then
    begin
      try
        seconds := StrToInt(Copy(eventName, 7, Length(eventName) - 7));
        window.setInterval(
          procedure
          begin
            ExecuteElementAction(el);
          end, seconds * 1000
        );
      except
        WriteLn('EHTML: Invalid interval in data-on: "' + eventName + '"');
      end;
    end
    else if eventName = 'revealed' then
    begin
      asm
        var observer = new IntersectionObserver(function(entries) {
          entries.forEach(function(entry) {
            if (entry.isIntersecting) {
              this.ExecuteElementAction(entry.target);
              observer.unobserve(entry.target);
            }
          }.bind(this));
        }.bind(this));
        observer.observe(el);
      end;
    end
    else if not ((eventName = 'load') or (eventName = 'every') or (eventName = 'revealed')) then
    begin
      asm
        el.addEventListener(eventName, function(e) {
          if ((eventFilter !== '') && (!e.target.matches(eventFilter))) return;
          this.ExecuteElementAction(el);
        }.bind(this));
      end;
    end;
  end;
end;

procedure SetupBoost;
var
  links: TJSNodeList;
  forms: TJSNodeList;
  i: Integer;
  link: TJSHTMLAnchorElement;
  form: TJSHTMLFormElement;

  procedure procEventSubmit(e: TJSEvent);
    begin
      e.preventDefault();
      ExecuteElementAction(form);
    end;
begin
  links := document.querySelectorAll('a[data-boost="true"]');
  forms := document.querySelectorAll('form[data-boost="true"]');
  
  for i := 0 to links.length - 1 do
  begin
    link := TJSHTMLAnchorElement(links[i]);
    link.addEventListener('click', procedure(e: TJSMouseEvent)
    begin
      e.preventDefault();
      ExecuteElementAction(link);
    end);
  end;
  
  for i := 0 to forms.length - 1 do
  begin
    form := TJSHTMLFormElement(forms[i]);
    form.addEventListener('submit', @procEventSubmit);
  end;
end;

procedure InitEHTML;
begin
  HandlerMap := TJSObject.new;
  SetupTriggers;
  SetupDataOnTriggers;
  SetupBoost;
end;

end.