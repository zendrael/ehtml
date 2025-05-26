unit ehtml;

{$mode objfpc}{$H+}

interface

uses
  JS, Web;

type
  THandlerProc = procedure(el: TJSHTMLElement; data: TJSFormData);

procedure Initialize;
procedure AddHandler(const name: string; proc: THandlerProc);

implementation

uses SysUtils;

var
  Handlers: TJSMap;

procedure AddHandler(const name: string; proc: THandlerProc);
begin
  Handlers.&Set(name, TJSMapProcCallBack(procedure(el: TJSHTMLElement; data: TJSFormData)
  begin
    proc(el, data);
  end));
end;

function ExtractFormData(el: TJSHTMLElement): TJSFormData;
var
  form: TJSHTMLFormElement;
  includeList: String;
  includeSelectors: TStringArray;
  i: Integer;
  extraEl: TJSHTMLElement;
begin
  if el.tagName = 'FORM' then
    Result := TJSFormData.New(TJSHTMLFormElement(el))
  else
  begin
    // form := TJSHTMLFormElement(el.closest('form'));
    // if Assigned(form) then
    //   Result := TJSFormData.New(form)
    // else
    //   Result := TJSFormData.New(nil);
  end;

  if el.hasAttribute('data-include') then
  begin
    includeList := el.getAttribute('data-include');
    includeSelectors := includeList.Split(',');
    for i := 0 to High(includeSelectors) do
    begin
      extraEl := TJSHTMLElement(document.querySelector(Trim(includeSelectors[i])));
      if Assigned(extraEl) and extraEl.hasAttribute('name') then
      begin
        WriteLn('Type:', extraEl.tagName);
        
        Result := TJSFormData.New(TJSHTMLFormElement(extraEl));
        // Result.append(extraEl.getAttribute('name'), extraEl['value']);
      end;
    end;
  end;
end;

function ResolveTargetElement(sourceEl: TJSHTMLElement; selector: string): TJSHTMLElement;
var
  relation, arg: String;
  sibling: TJSNode;
begin
  if selector = 'this' then
    Exit(sourceEl)
  else if selector = 'parent' then
    Exit(TJSHTMLElement(sourceEl.parentElement))
  else if selector.StartsWith('closest ') then
    // Exit(TJSHTMLElement(sourceEl.closest(Trim(Copy(selector, 9, Length(selector))))))
    WriteLn('closest not implemented')
  else if selector.StartsWith('next') then
  begin
    sibling := sourceEl.nextElementSibling;
    if selector = 'next' then
      Exit(TJSHTMLElement(sibling))
    else
    begin
      arg := Trim(Copy(selector, 5, Length(selector)));
      while Assigned(sibling) do
      begin
        if TJSHTMLElement(sibling).matches(arg) then
          Exit(TJSHTMLElement(sibling));
        sibling := TJSHTMLElement(sibling).nextElementSibling;
      end;
    end;
  end
  else if selector.StartsWith('previous') then
  begin
    sibling := sourceEl.previousElementSibling;
    if selector = 'previous' then
      Exit(TJSHTMLElement(sibling))
    else
    begin
      arg := Trim(Copy(selector, 9, Length(selector)));
      while Assigned(sibling) do
      begin
        if TJSHTMLElement(sibling).matches(arg) then
          Exit(TJSHTMLElement(sibling));
        sibling := TJSHTMLElement(sibling).nextElementSibling;
      end;
    end;
  end
  else
    Exit(TJSHTMLElement(document.querySelector(selector)));
end;

procedure HandleClick(e: TJSMouseEvent);
var
  el, target: TJSHTMLElement;
  url, method, swap, handlerName: String;
  data: TJSFormData;
  xhr: TJSXMLHttpRequest;
  // handler: TJSCallback;
begin
  el := TJSHTMLElement(e.target);
  while Assigned(el) and not el.hasAttribute('data-get') and
                        not el.hasAttribute('data-post') and
                        not el.hasAttribute('data-put') and
                        not el.hasAttribute('data-delete') and
                        not el.hasAttribute('data-patch') and
                        not el.hasAttribute('data-handler') do
    el := TJSHTMLElement(el.parentElement);

  if not Assigned(el) then Exit;

  if el.hasAttribute('data-confirm') then
  begin
    if not window.confirm(el.getAttribute('data-confirm')) then
    begin
      e.preventDefault;
      Exit;
    end;
  end;

  if el.hasAttribute('data-handler') then
  begin
    handlerName := el.getAttribute('data-handler');
    if Handlers.has(handlerName) then
    begin
      data := ExtractFormData(el);
      THandlerProc(TJSMapProcCallBack(Handlers.get(handlerName)))(el, data);
    end;
    Exit;
  end;

  e.preventDefault;

  if el.hasAttribute('data-get') then
  begin
    method := 'GET';
    url := el.getAttribute('data-get');
  end
  else if el.hasAttribute('data-post') then
  begin
    method := 'POST';
    url := el.getAttribute('data-post');
  end
  else if el.hasAttribute('data-put') then
  begin
    method := 'PUT';
    url := el.getAttribute('data-put');
  end
  else if el.hasAttribute('data-delete') then
  begin
    method := 'DELETE';
    url := el.getAttribute('data-delete');
  end
  else if el.hasAttribute('data-patch') then
  begin
    method := 'PATCH';
    url := el.getAttribute('data-patch');
  end
  else Exit;

  data := ExtractFormData(el);
  xhr := TJSXMLHttpRequest.new;
  xhr.open(method, url);
  xhr.addEventListener('load', procedure
  begin
    if el.hasAttribute('data-target') then
    begin
      target := ResolveTargetElement(el, el.getAttribute('data-target'));
    end else begin
      target := el;
    end;

    if Assigned(target) then
    begin
      swap := el.getAttribute('data-swap');
      if swap = 'outerHTML' then
        target.outerHTML := xhr.responseText
      else if swap = 'beforebegin' then
        target.insertAdjacentHTML('beforebegin', xhr.responseText)
      else if swap = 'afterbegin' then
        target.insertAdjacentHTML('afterbegin', xhr.responseText)
      else if swap = 'beforeend' then
        target.insertAdjacentHTML('beforeend', xhr.responseText)
      else if swap = 'afterend' then
        target.insertAdjacentHTML('afterend', xhr.responseText)
      else
        target.innerHTML := xhr.responseText;
    end;
  end);
  xhr.send(data);
end;

procedure ProcessTriggers;
var
  els: TJSNodeList;
  i: Integer;
  el: TJSHTMLElement;
  trigger: string;

  procedure procedureEvent(e: TJSEvent);
  begin
    el.click;
  end;

  procedure SetupEventListener(eventName: string);
  begin
    el.addEventListener(eventName, @procedureEvent);
  end;

  procedure SetupIntervalTrigger(seconds: Double);
  begin
    window.setInterval(procedure
    begin
      el.click;
    end, Trunc(seconds * 1000));
  end;

begin
  els := document.querySelectorAll('[data-trigger]');
  for i := 0 to els.length - 1 do
  begin
    el := TJSHTMLElement(els.item(i));
    trigger := el.getAttribute('data-trigger');

    if trigger = 'load' then
      window.setTimeout(procedure
      begin
        el.click;
      end, 10)
    else if trigger = 'click' then
      SetupEventListener('click')
    else if trigger = 'change' then
      SetupEventListener('change')
    else if trigger = 'mouseover' then
      SetupEventListener('mouseover')
    else if trigger = 'dblclick' then
      SetupEventListener('dblclick')
    else if trigger = 'keyup' then
      SetupEventListener('keyup')
    else if trigger.StartsWith('every ') and trigger.EndsWith('s') then
    begin
      try
        SetupIntervalTrigger(StrToFloat(Copy(trigger, 7, Length(trigger)-7)));
      except
        // Ignora erro de conversão
      end;
    end;
  end;
end;

procedure Initialize;
begin
  Handlers := TJSMap.new;
  document.addEventListener('click', @HandleClick);
  ProcessTriggers;
end;

end.