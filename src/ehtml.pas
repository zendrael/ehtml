unit ehtml;

{$mode objfpc}{$H+}

interface

uses
  JS, Web, Classes, SysUtils;

const
  EHTML_VERSION = '0.8.0';

/// Type alias for Pascal handler procedures
type
  TEhtmlHandler = procedure(el: TJSHTMLElement); 

var
  /// Stores all registered handlers linked to `data-handler` attributes
  HandlerMap: specialize TStringHashMap<TEhtmlHandler>;

/// Registers a named handler to be used with `data-handler="handlerName"`
procedure AddHandler(const name: string; handler: TEhtmlHandler);

/// Initializes EHTML behavior for all DOM elements
procedure InitializeEhtml;

implementation

uses
  Types;

procedure AddHandler(const name: string; handler: TEhtmlHandler);
begin
  HandlerMap[name] := handler;
end;

function GetAttribute(el: TJSHTMLElement; const attr: string): string;
begin
  if el.hasAttribute(attr) then
    Result := el.getAttribute(attr)
  else
    Result := '';
end;

function FindTarget(el: TJSHTMLElement; targetStr: string): TJSHTMLElement;
var
  target: TJSHTMLElement;
begin
  if (targetStr = '') or (targetStr = 'this') then
    Exit(el)
  else if targetStr.StartsWith('closest ') then
    Exit(TJSHTMLElement(el.closest(Copy(targetStr, 9, Length(targetStr)))));

  if targetStr = 'next' then
    target := TJSHTMLElement(el.nextElementSibling)
  else if targetStr = 'previous' then
    target := TJSHTMLElement(el.previousElementSibling)
  else
    target := TJSHTMLElement(document.querySelector(targetStr));
  
  Exit(target);
end;

procedure PerformSwap(target: TJSHTMLElement; content: string; swapType: string);
begin
  if target = nil then Exit;
  case swapType of
    'outerHTML': target.outerHTML := content;
    'beforebegin': target.insertAdjacentHTML('beforebegin', content);
    'afterbegin': target.insertAdjacentHTML('afterbegin', content);
    'beforeend': target.insertAdjacentHTML('beforeend', content);
    'afterend': target.insertAdjacentHTML('afterend', content);
    else target.innerHTML := content;
  end;
end;

procedure ApplyIndicator(indicatorSel: string; show: boolean);
var
  el: TJSHTMLElement;
begin
  if indicatorSel = '' then Exit;
  el := TJSHTMLElement(document.querySelector(indicatorSel));
  if el <> nil then
  begin
    if show then
      el.removeAttribute('style')
    else
      el.setAttribute('style', 'display: none');
  end;
end;

procedure HandleEvent(el: TJSHTMLElement);
var
  method, url, swap, targetSel, confirmMsg, includeSel, vals, params, headers, handlerName: string;
  targetEl, indicatorEl: TJSHTMLElement;
  xhr: TJSXMLHttpRequest;
begin
  confirmMsg := GetAttribute(el, 'data-confirm');
  if (confirmMsg <> '') and (not window.confirm(confirmMsg)) then Exit;

  method := LowerCase(GetAttribute(el, 'data-get'));
  if method = '' then method := LowerCase(GetAttribute(el, 'data-post'));
  if method = '' then method := LowerCase(GetAttribute(el, 'data-put'));
  if method = '' then method := LowerCase(GetAttribute(el, 'data-delete'));
  if method = '' then method := LowerCase(GetAttribute(el, 'data-patch'));

  url := GetAttribute(el, 'data-get');
  if url = '' then url := GetAttribute(el, 'data-post');
  if url = '' then url := GetAttribute(el, 'data-put');
  if url = '' then url := GetAttribute(el, 'data-delete');
  if url = '' then url := GetAttribute(el, 'data-patch');

  targetSel := GetAttribute(el, 'data-target');
  targetEl := FindTarget(el, targetSel);
  swap := GetAttribute(el, 'data-swap');
  if swap = '' then swap := 'innerHTML';

  includeSel := GetAttribute(el, 'data-include');
  vals := GetAttribute(el, 'data-vals');
  params := GetAttribute(el, 'data-params');
  headers := GetAttribute(el, 'data-headers');

  ApplyIndicator(GetAttribute(el, 'data-indicator'), True);

  xhr := TJSXMLHttpRequest.new;
  xhr.open(method, url);

  if headers <> '' then
    try
      var parsed := TJSJSON.parse(headers);
      for var k in JSForIn(parsed) do
        xhr.setRequestHeader(k, parsed[k]);
    except
      console.warn('Invalid data-headers JSON');
    end;

  xhr.onload := procedure
  begin
    ApplyIndicator(GetAttribute(el, 'data-indicator'), False);
    PerformSwap(targetEl, xhr.responseText, swap);
  end;

  if method = 'get' then
    xhr.send
  else
    xhr.send(nil); // TODO: add body from form or data-vals/params
end;

procedure InitHandlers;
begin
  for var node in document.querySelectorAll('[data-handler]') do
  begin
    var el := TJSHTMLElement(node);
    var trig := GetAttribute(el, 'data-trigger');
    if trig = '' then trig := 'click';

    el.addEventListener(trig, procedure()
    var name := GetAttribute(el, 'data-handler');
    begin
      if HandlerMap.contains(name) then
        HandlerMap[name](el);
    end);
  end;
end;

procedure InitActions;
begin
  for var node in document.querySelectorAll('[data-get], [data-post], [data-put], [data-delete], [data-patch]') do
  begin
    var el := TJSHTMLElement(node);
    var trig := GetAttribute(el, 'data-trigger');
    if trig = '' then trig := 'click';

    el.addEventListener(trig, procedure()
    begin
      HandleEvent(el);
    end);
  end;
end;

procedure InitializeEhtml;
begin
  if HandlerMap = nil then
    HandlerMap := specialize TStringHashMap<TEhtmlHandler>.Create;

  InitHandlers;
  InitActions;
end;

initialization
  InitializeEhtml;

end.
