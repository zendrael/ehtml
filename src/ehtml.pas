// ehtml.pas - Biblioteca EHTML (Enhanced HTML)
// Compatível com pas2JS 3.0.1
// Inspirado em htmx, mas usando atributos data-* ao invés de hx-*

unit ehtml;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, JS, Web;

type
  TEHTMLHandler = procedure(el: TJSHTMLElement);

var
  Handlers: TJSMap;

procedure InitEHTML;
procedure AddHandler(const name: string; handler: TEHTMLHandler);

implementation

var
  Loaded: Boolean = False;

procedure AddHandler(const name: string; handler: TEHTMLHandler);
begin
  Handlers.set(name, TJSValue(handler));
end;

function FindTarget(el: TJSHTMLElement; sel: string): TJSHTMLElement;
var
  selector, mode: String;
  parent: TJSNode;
begin
  Result := nil;
  sel := Trim(sel);
  if sel = '' then exit;

  if Pos('closest ', sel) = 1 then
  begin
    selector := Copy(sel, 9, Length(sel));
    if el.closest(selector) <> nil then
      Result := TJSHTMLElement(el.closest(selector));
  end
  else if Pos('next ', sel) = 1 then
  begin
    selector := Copy(sel, 6, Length(sel));
    if (el.nextElementSibling <> nil) and TJSHTMLElement(el.nextElementSibling).matches(selector) then
      Result := TJSHTMLElement(el.nextElementSibling);
  end
  else if Pos('previous ', sel) = 1 then
  begin
    selector := Copy(sel, 10, Length(sel));
    if (el.previousElementSibling <> nil) and TJSHTMLElement(el.previousElementSibling).matches(selector) then
      Result := TJSHTMLElement(el.previousElementSibling);
  end
  else
    Result := TJSHTMLElement(document.querySelector(sel));
end;

procedure ProcessElement(el: TJSHTMLElement);
var
  verb, url, swap, trigger, targetSel, confirmMsg, pushUrl, replaceUrl: string;
  targetEl: TJSHTMLElement;
  isSync, isPending: Boolean;
  formData: TJSFormData;
  headers: TJSObject;
  requestInit: TJSObject;
  handlerName: String;
  handler: TEHTMLHandler;

  procedure CleanupPending;
  begin
    if el.hasAttribute('data-sync') then
      el.removeAttribute('data-ehtml-pending');
  end;

begin
  // Confirmação opcional
  if el.hasAttribute('data-confirm') then
  begin
    confirmMsg := el.getAttribute('data-confirm');
    if not window.confirm(confirmMsg) then exit;
  end;

  // Evita múltiplas requisições simultâneas se data-sync estiver presente
  if el.hasAttribute('data-sync') then
  begin
    if el.hasAttribute('data-ehtml-pending') then exit;
    el.setAttribute('data-ehtml-pending', 'true');
  end;

  // Obtém verbo e URL
  verb := LowerCase(el.getAttributeNames().find(@(s) => Copy(s, 1, 5) = 'data-')
           .filter(@(s) => (s = 'data-get') or (s = 'data-post') or (s = 'data-put') or (s = 'data-delete') or (s = 'data-patch'))[0]);
  url := el.getAttribute(verb);
  verb := Copy(verb, 6, Length(verb));

  // Target
  targetSel := el.getAttribute('data-target');
  targetEl := FindTarget(el, targetSel);

  // Swap
  if el.hasAttribute('data-swap') then
    swap := el.getAttribute('data-swap') else
    swap := 'innerHTML';

  // Headers (simples, JSON string)
  headers := new(['Content-Type', 'application/x-www-form-urlencoded']);
  if el.hasAttribute('data-headers') then
  begin
    try
      var extra := TJSJSON.parse(el.getAttribute('data-headers'));
      var key: JSString;
      for key in Object.keys(extra) do
        headers[key] := extra[key];
    except
      console.warn('Invalid data-headers JSON');
    end;
  end;

  // Form data / parâmetros (por enquanto do próprio elemento apenas)
  formData := new(TJSFormData);
  if el.hasAttribute('data-vals') then
  begin
    var kv := TJSJSON.parse(el.getAttribute('data-vals'));
    var k: JSString;
    for k in Object.keys(kv) do
      formData.append(k, kv[k]);
  end;

  // Disable (temporário)
  if el.hasAttribute('data-disable') then
    el.setAttribute('disabled', 'true');

  // Indicador
  var indicator: TJSHTMLElement;
  if el.hasAttribute('data-indicator') then
  begin
    indicator := TJSHTMLElement(document.querySelector(el.getAttribute('data-indicator')));
    if indicator <> nil then
      indicator.style.setProperty('display', '');
  end;

  // Requisição
  requestInit := new;
  requestInit['method'] := UpperCase(verb);
  requestInit['headers'] := headers;
  if (verb <> 'get') then
    requestInit['body'] := formData;

  window.fetch(url, requestInit).then(@(response: TJSResponse)
  begin
    response.text().then(@(html: string)
    begin
      // Atualiza conteúdo
      if (targetEl <> nil) then
      begin
        if swap = 'outerHTML' then
          targetEl.outerHTML := html
        else if swap = 'beforebegin' then
          targetEl.insertAdjacentHTML('beforebegin', html)
        else if swap = 'afterbegin' then
          targetEl.insertAdjacentHTML('afterbegin', html)
        else if swap = 'beforeend' then
          targetEl.insertAdjacentHTML('beforeend', html)
        else if swap = 'afterend' then
          targetEl.insertAdjacentHTML('afterend', html)
        else
          targetEl.innerHTML := html;
      end;

      // Restaura botão
      if el.hasAttribute('data-disable') then
        el.removeAttribute('disabled');

      // Oculta indicador
      if indicator <> nil then
        indicator.style.setProperty('display', 'none');

      // URL: push ou replace
      if el.hasAttribute('data-replace-url') then
      begin
        replaceUrl := el.getAttribute('data-replace-url');
        if replaceUrl <> '' then
          window.history.replaceState(nil, '', replaceUrl);
      end;
      if el.hasAttribute('data-push-url') then
      begin
        pushUrl := el.getAttribute('data-push-url');
        if pushUrl <> '' then
          window.history.pushState(nil, '', pushUrl);
      end;

      CleanupPending;
    end);
  end).catch(@(err: JSValue)
  begin
    CleanupPending;
    console.error('EHTML request failed:', err);
  end);
end;

procedure InitEHTML;
begin
  if Loaded then exit;
  Loaded := True;

  Handlers := TJSMap.new;

  document.addEventListener('click', procedure(e: TJSEvent)
  var
    target: TJSHTMLElement;
    attr: String;
  begin
    target := TJSHTMLElement(e.target);
    if target = nil then exit;

    // Verifica se há algum data-trigger="click"
    if target.hasAttribute('data-trigger') and (target.getAttribute('data-trigger') = 'click') then
    begin
      e.preventDefault;
      ProcessElement(target);
    end;

    // data-handler
    if target.hasAttribute('data-handler') then
    begin
      var hname := target.getAttribute('data-handler');
      if Handlers.has(hname) then
        TEHTMLHandler(Handlers.get(hname))(target);
    end;
  end);
end;

end.
