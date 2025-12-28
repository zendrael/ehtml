unit EHTMLunit;

{$mode objfpc}
{$modeswitch externalclass}

interface

uses
  JS, Web, sysutils;

type
  // HTTP Methods
  THTTPMethod = (hmGET, hmPOST, hmPUT, hmDELETE, hmPATCH);
  
  // Swap strategies
  TSwapStrategy = (ssInnerHTML, ssOuterHTML, ssBeforeBegin, ssAfterBegin, ssBeforeEnd, ssAfterEnd, ssDelete, ssNone);
  
  // Trigger events
  TTriggerEvent = (teClick, teChange, teSubmit, teLoad, teFocus, teBlur, teKeyUp, teKeyDown, teMouseOver, teMouseOut);
  
  // Custom handler reference
  TProcedureRef = reference to procedure(Element: TJSHTMLElement);

  // Request configuration
  TEHTMLRequest = class
  public
    Method: THTTPMethod;
    URL: string;
    Target: string;
    Swap: TSwapStrategy;
    Trigger: TTriggerEvent;
    Headers: TJSObject;
    Element: TJSHTMLElement;
    
    // === NOVOS CAMPOS PARA ALTA PRIORIDADE ===
    Indicator: string;          // data-indicator
    Confirm: string;           // data-confirm
    PushURL: Boolean;          // data-push-url
    ReplaceURL: Boolean;       // data-replace-url
    ErrorTarget: string;       // data-error-target
    ErrorSwap: TSwapStrategy;  // data-error-swap
    // =========================================
    
    constructor Create(AElement: TJSHTMLElement);
    procedure Execute;
  end;
  
  // Main EHTML class
  TEHTML = class
  private
    class var FInstance: TEHTML;
    FProcessedElements: TJSArray;
    
    function ParseHTTPMethod(const AValue: string): THTTPMethod;
    function ParseSwapStrategy(const AValue: string): TSwapStrategy;
    function ParseTriggerEvent(const AValue: string): TTriggerEvent;
    function GetEventName(ATrigger: TTriggerEvent): string;
    function GetTargetElement(const ASelector: string; ASourceElement: TJSHTMLElement): TJSHTMLElement;
    function SerializeForm(AForm: TJSHTMLFormElement): string;
    function ParseJSONHeaders(const AHeadersStr: string): TJSObject;
    procedure ProcessElement(AElement: TJSHTMLElement);
    procedure AttachEventListener(AElement: TJSHTMLElement; AEventName: string; ARequest: TEHTMLRequest);
    procedure HandleResponse(ARequest: TEHTMLRequest; AResponse: string);
    procedure SwapContent(ATarget: TJSHTMLElement; AContent: string; AStrategy: TSwapStrategy);
    
    // === NOVOS MÉTODOS PARA ALTA PRIORIDADE ===
    procedure ShowIndicator(const ASelector: string);
    procedure HideIndicator(const ASelector: string);
    function ShowConfirmDialog(const AMessage: string): Boolean;
    procedure UpdateURL(const AURL: string; APush: Boolean);
    procedure HandleError(ARequest: TEHTMLRequest; AError: string; AStatus: Integer);
    procedure AddCSSClasses(AElement: TJSHTMLElement; const AClass: string);
    procedure RemoveCSSClasses(AElement: TJSHTMLElement; const AClass: string);
    // =============================================
    
  public
    constructor Create;
    destructor Destroy; override;
    
    class function Instance: TEHTML;
    procedure Initialize;
    procedure AddHandler(const Name: string; Handler: TProcedureRef);
    procedure Process(AElement: TJSHTMLElement = nil);
    procedure ProcessSelector(const ASelector: string);
  end;

// Global functions
procedure EHTMLInit;
function EHTML: TEHTML;

implementation

var
  HandlerMap: TJSObject;

const
  HTTP_METHOD_NAMES: array[THTTPMethod] of string = ('GET', 'POST', 'PUT', 'DELETE', 'PATCH');
  TRIGGER_EVENTS: array[TTriggerEvent] of string = ('click', 'change', 'submit', 'load', 'focus', 'blur', 'keyup', 'keydown', 'mouseover', 'mouseout');

// TEHTMLRequest implementation

constructor TEHTMLRequest.Create(AElement: TJSHTMLElement);
var
  methodAttr, targetAttr, swapAttr, triggerAttr: string;
begin
  Element := AElement;
  
  // Parse HTTP method from data-* attributes
  methodAttr := '';
  if AElement.hasAttribute('data-get') then
  begin
    Method := hmGET;
    URL := AElement.getAttribute('data-get');
  end
  else if AElement.hasAttribute('data-post') then
  begin
    Method := hmPOST;
    URL := AElement.getAttribute('data-post');
  end
  else if AElement.hasAttribute('data-put') then
  begin
    Method := hmPUT;
    URL := AElement.getAttribute('data-put');
  end
  else if AElement.hasAttribute('data-delete') then
  begin
    Method := hmDELETE;
    URL := AElement.getAttribute('data-delete');
  end
  else if AElement.hasAttribute('data-patch') then
  begin
    Method := hmPATCH;
    URL := AElement.getAttribute('data-patch');
  end
  else
  begin
    Method := hmGET;
    URL := '';
  end;
  
  // Parse target
  if AElement.hasAttribute('data-target') then
    Target := AElement.getAttribute('data-target')
  else
    Target := '';
    
  // Parse swap strategy
  if AElement.hasAttribute('data-swap') then
    Swap := TEHTML.Instance.ParseSwapStrategy(AElement.getAttribute('data-swap'))
  else
    Swap := ssInnerHTML;
    
  // Parse trigger
  if AElement.hasAttribute('data-trigger') then
    Trigger := TEHTML.Instance.ParseTriggerEvent(AElement.getAttribute('data-trigger'))
  else
  begin
    // Default triggers based on element type
    if (AElement.tagName = 'FORM') then
      Trigger := teSubmit
    else if (AElement.tagName = 'INPUT') or (AElement.tagName = 'SELECT') or (AElement.tagName = 'TEXTAREA') then
      Trigger := teChange
    else
      Trigger := teClick;
  end;
  
  // Parse custom headers
  Headers := nil;
  if AElement.hasAttribute('data-headers') then
    Headers := TEHTML.Instance.ParseJSONHeaders(AElement.getAttribute('data-headers'));
  
  // === PARSE NOVOS ATRIBUTOS ===
  // Parse indicator
  if AElement.hasAttribute('data-indicator') then
    Indicator := AElement.getAttribute('data-indicator')
  else
    Indicator := '';
    
  // Parse confirm
  if AElement.hasAttribute('data-confirm') then
    Confirm := AElement.getAttribute('data-confirm')
  else
    Confirm := '';
    
  // Parse push-url
  PushURL := AElement.hasAttribute('data-push-url') and 
             (LowerCase(AElement.getAttribute('data-push-url')) <> 'false');
             
  // Parse replace-url
  ReplaceURL := AElement.hasAttribute('data-replace-url') and 
                (LowerCase(AElement.getAttribute('data-replace-url')) <> 'false');
                
  // Parse error handling
  if AElement.hasAttribute('data-error-target') then
    ErrorTarget := AElement.getAttribute('data-error-target')
  else
    ErrorTarget := '';
    
  if AElement.hasAttribute('data-error-swap') then
    ErrorSwap := TEHTML.Instance.ParseSwapStrategy(AElement.getAttribute('data-error-swap'))
  else
    ErrorSwap := ssInnerHTML;
  // ==============================
end;

procedure TEHTMLRequest.Execute;
var
  xhr: TJSXMLHttpRequest;
  formData, urlParams: string;
  form: TJSHTMLFormElement;
  handlerName: string;
  handler: TProcedureRef;
begin
  // === CONFIRMAÇÃO ===
  if Confirm <> '' then
  begin
    if not TEHTML.Instance.ShowConfirmDialog(Confirm) then
      Exit; // Usuário cancelou
  end;
  // ==================

  handlerName := Element.getAttribute('data-handler');
  if (handlerName <> '') and (HandlerMap.hasOwnProperty(handlerName)) then
  begin
    handler := TProcedureRef(HandlerMap[handlerName]);
    if Assigned(handler) then
      handler(Element);
  end;

  // If there is no endpoint, skip AJAX request (handler only)
  if (URL = '') then Exit;

  // === MOSTRAR INDICATOR ===
  if Indicator <> '' then
    TEHTML.Instance.ShowIndicator(Indicator);
  // ========================
  
  // === ADICIONAR CLASSES CSS ===
  TEHTML.Instance.AddCSSClasses(Element, 'ehtml-request');
  // =============================

  xhr := TJSXMLHttpRequest.new;
  
  // Prepare form data if needed
  formData := '';
  if (Method <> hmGET) and (Element.tagName = 'FORM') then
  begin
    form := TJSHTMLFormElement(Element);
    formData := TEHTML.Instance.SerializeForm(form);
  end;
  
  // Prepare URL with parameters for GET requests
  urlParams := '';
  if (Method = hmGET) and (Element.tagName = 'FORM') then
  begin
    form := TJSHTMLFormElement(Element);
    urlParams := TEHTML.Instance.SerializeForm(form);
    if urlParams <> '' then
    begin
      if Pos('?', URL) > 0 then
        URL := URL + '&' + urlParams
      else
        URL := URL + '?' + urlParams;
    end;
  end;
  
  // Configure request
  xhr.open(HTTP_METHOD_NAMES[Method], URL, true);
  
  // Set headers
  if Method in [hmPOST, hmPUT, hmPATCH] then
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    
  // Set custom headers
  if Assigned(Headers) then
  begin
    asm
      var hdrs = pas.Headers;
      for (var key in hdrs) {
        if (hdrs.hasOwnProperty(key)) {
          xhr.setRequestHeader(key, hdrs[key]);
        }
      }
    end;
  end;
  
  // Set up response handler
  xhr.onreadystatechange := procedure
  begin
    if xhr.readyState = 4 then
    begin
      // === REMOVER CLASSES E INDICATOR ===
      TEHTML.Instance.RemoveCSSClasses(Element, 'ehtml-request');
      if Indicator <> '' then
        TEHTML.Instance.HideIndicator(Indicator);
      // ==================================
      
      if (xhr.status >= 200) and (xhr.status < 300) then
      begin
        // === ATUALIZAR URL SE NECESSÁRIO ===
        if PushURL or ReplaceURL then
          TEHTML.Instance.UpdateURL(URL, PushURL);
        // ===================================
        
        TEHTML.Instance.HandleResponse(Self, xhr.responseText);
      end
      else
      begin
        // === TRATAMENTO DE ERRO ===
        TEHTML.Instance.HandleError(Self, xhr.responseText, xhr.status);
        // =========================
      end;
    end;
  end;
  
  // Send request
  if formData <> '' then
    xhr.send(formData)
  else
    xhr.send;
end;

// TEHTML implementation

constructor TEHTML.Create;
begin
  inherited Create;
  FProcessedElements := TJSArray.new;
end;

destructor TEHTML.Destroy;
begin
  FProcessedElements := nil;
  inherited Destroy;
end;

class function TEHTML.Instance: TEHTML;
begin
  if not Assigned(FInstance) then
    FInstance := TEHTML.Create;
  Result := FInstance;
end;

// === IMPLEMENTAÇÃO DOS NOVOS MÉTODOS ===

procedure TEHTML.ShowIndicator(const ASelector: string);
var
  indicator: TJSHTMLElement;
begin
  indicator := GetTargetElement(ASelector, nil);
  if Assigned(indicator) then
  begin
    indicator.style.setProperty('display', 'block');
    AddCSSClasses(indicator, 'ehtml-indicator-active');
  end;
end;

procedure TEHTML.HideIndicator(const ASelector: string);
var
  indicator: TJSHTMLElement;
begin
  indicator := GetTargetElement(ASelector, nil);
  if Assigned(indicator) then
  begin
    indicator.style.setProperty('display', 'none');
    RemoveCSSClasses(indicator, 'ehtml-indicator-active');
  end;
end;

function TEHTML.ShowConfirmDialog(const AMessage: string): Boolean;
begin
  asm
    pas.Result = confirm(AMessage);
  end;
end;

procedure TEHTML.UpdateURL(const AURL: string; APush: Boolean);
begin
  if APush then
  begin
    asm
      if (window.history && window.history.pushState) {
        window.history.pushState(null, '', AURL);
      }
    end;
  end
  else
  begin
    asm
      if (window.history && window.history.replaceState) {
        window.history.replaceState(null, '', AURL);
      }
    end;
  end;
end;

procedure TEHTML.HandleError(ARequest: TEHTMLRequest; AError: string; AStatus: Integer);
var
  targetElement: TJSHTMLElement;
  errorMessage: string;
begin
  // Log do erro
  console.error('EHTML request failed:', AStatus, AError);
  
  // Adicionar classe de erro ao elemento
  AddCSSClasses(ARequest.Element, 'ehtml-error');
  
  // Se tem target específico para erro, usar ele
  if ARequest.ErrorTarget <> '' then
  begin
    targetElement := GetTargetElement(ARequest.ErrorTarget, ARequest.Element);
    if Assigned(targetElement) then
    begin
      errorMessage := AError;
      if errorMessage = '' then
        errorMessage := 'Request failed with status: ' + IntToStr(AStatus);
      SwapContent(targetElement, errorMessage, ARequest.ErrorSwap);
    end;
  end;
end;

procedure TEHTML.AddCSSClasses(AElement: TJSHTMLElement; const AClass: string);
begin
  if Assigned(AElement) then
  begin
    asm
      AElement.classList.add(AClass);
    end;
  end;
end;

procedure TEHTML.RemoveCSSClasses(AElement: TJSHTMLElement; const AClass: string);
begin
  if Assigned(AElement) then
  begin
    asm
      AElement.classList.remove(AClass);
    end;
  end;
end;

// ======================================

function TEHTML.ParseHTTPMethod(const AValue: string): THTTPMethod;
var
  upperValue: string;
begin
  upperValue := UpperCase(AValue);
  case upperValue of
    'GET': Result := hmGET;
    'POST': Result := hmPOST;
    'PUT': Result := hmPUT;
    'DELETE': Result := hmDELETE;
    'PATCH': Result := hmPATCH;
  else
    Result := hmGET;
  end;
end;

function TEHTML.ParseSwapStrategy(const AValue: string): TSwapStrategy;
var
  lowerValue: string;
begin
  lowerValue := LowerCase(AValue);
  case lowerValue of
    'innerhtml': Result := ssInnerHTML;
    'outerhtml': Result := ssOuterHTML;
    'beforebegin': Result := ssBeforeBegin;
    'afterbegin': Result := ssAfterBegin;
    'beforeend': Result := ssBeforeEnd;
    'afterend': Result := ssAfterEnd;
    'delete': Result := ssDelete;
    'none': Result := ssNone;
  else
    Result := ssInnerHTML;
  end;
end;

function TEHTML.ParseTriggerEvent(const AValue: string): TTriggerEvent;
var
  lowerValue: string;
begin
  lowerValue := LowerCase(AValue);
  case lowerValue of
    'click': Result := teClick;
    'change': Result := teChange;
    'submit': Result := teSubmit;
    'load': Result := teLoad;
    'focus': Result := teFocus;
    'blur': Result := teBlur;
    'keyup': Result := teKeyUp;
    'keydown': Result := teKeyDown;
    'mouseover': Result := teMouseOver;
    'mouseout': Result := teMouseOut;
  else
    Result := teClick;
  end;
end;

function TEHTML.GetEventName(ATrigger: TTriggerEvent): string;
begin
  Result := TRIGGER_EVENTS[ATrigger];
end;

function TEHTML.GetTargetElement(const ASelector: string; ASourceElement: TJSHTMLElement): TJSHTMLElement;
begin
  if ASelector = '' then
    Result := ASourceElement
  else if ASelector = 'this' then
    Result := ASourceElement
  else if Copy(ASelector, 1, 1) = '#' then
    Result := TJSHTMLElement(document.getElementById(Copy(ASelector, 2, Length(ASelector))))
  else if Copy(ASelector, 1, 1) = '.' then
    Result := TJSHTMLElement(document.querySelector(ASelector))
  else if ASelector = 'body' then
    Result := TJSHTMLElement(document.body)
  else
    Result := TJSHTMLElement(document.querySelector(ASelector));
end;

function TEHTML.SerializeForm(AForm: TJSHTMLFormElement): string;
var
  elements: TJSHTMLCollection;
  element: TJSHTMLElement;
  input: TJSHTMLInputElement;
  select: TJSHTMLSelectElement;
  textarea: TJSHTMLTextAreaElement;
  i: Integer;
  name, value: string;
  params: array of string;
  paramCount: Integer;
begin
  SetLength(params, 0);
  paramCount := 0;
  
  elements := AForm.elements;
  
  for i := 0 to elements.length - 1 do
  begin
    element := TJSHTMLElement(elements.item(i));
    name := '';
    value := '';
    
    // Get name attribute
    if element.hasAttribute('name') then
      name := element.getAttribute('name');
      
    if name = '' then continue;
    
    // Get value based on element type
    if element.tagName = 'INPUT' then
    begin
      input := TJSHTMLInputElement(element);
      if (input._type = 'checkbox') or (input._type = 'radio') then
      begin
        if input.checked then
          value := input.value;
      end
      else
        value := input.value;
    end
    else if element.tagName = 'SELECT' then
    begin
      select := TJSHTMLSelectElement(element);
      value := select.value;
    end
    else if element.tagName = 'TEXTAREA' then
    begin
      textarea := TJSHTMLTextAreaElement(element);
      value := textarea.value;
    end;
    
    // Add to params if we have a value (or it's not a checkbox/radio)
    if (value <> '') or ((element.tagName <> 'INPUT') or 
       ((TJSHTMLInputElement(element)._type <> 'checkbox') and 
        (TJSHTMLInputElement(element)._type <> 'radio'))) then
    begin
      SetLength(params, paramCount + 1);
      asm
        params[paramCount] = encodeURIComponent(name) + '=' + encodeURIComponent(value);
      end;
      Inc(paramCount);
    end;
  end;
  
  Result := '';
  for i := 0 to High(params) do
  begin
    if i > 0 then Result := Result + '&';
    Result := Result + params[i];
  end;
end;

function TEHTML.ParseJSONHeaders(const AHeadersStr: string): TJSObject;
begin
  Result := nil;
  if AHeadersStr <> '' then
  begin
    try
      asm
        pas.Result = JSON.parse(AHeadersStr);
      end;
    except
      on E: Exception do
      begin
        console.warn('EHTML: Invalid JSON in data-headers:', AHeadersStr);
        Result := nil;
      end;
    end;
  end;
end;

procedure TEHTML.ProcessElement(AElement: TJSHTMLElement);
var
  request: TEHTMLRequest;
  eventName: string;
  hasEHTMLAttr: Boolean;
begin
  // Check if element has any EHTML or handler attributes
  hasEHTMLAttr := AElement.hasAttribute('data-get') or
                  AElement.hasAttribute('data-post') or
                  AElement.hasAttribute('data-put') or
                  AElement.hasAttribute('data-delete') or
                  AElement.hasAttribute('data-patch') or
                  AElement.hasAttribute('data-handler');

  if not hasEHTMLAttr then Exit;

  // Check if already processed
  if FProcessedElements.indexOf(AElement) >= 0 then Exit;

  // Create request configuration
  request := TEHTMLRequest.Create(AElement);

  // Get event name
  eventName := GetEventName(request.Trigger);

  // Attach event listener
  AttachEventListener(AElement, eventName, request);

  // Mark as processed
  FProcessedElements.push(AElement);
end;

procedure TEHTML.AttachEventListener(AElement: TJSHTMLElement; AEventName: string; ARequest: TEHTMLRequest);
var
  procedure procEventListener(event: TJSEvent);
  begin
    // Prevent default behavior for forms and links
    if (AEventName = 'submit') or 
       ((AEventName = 'click') and (AElement.tagName = 'A')) then
      event.preventDefault;
      
    // Execute the request
    ARequest.Execute;
  end;
begin
  AElement.addEventListener(AEventName, @procEventListener);
end;

procedure TEHTML.HandleResponse(ARequest: TEHTMLRequest; AResponse: string);
var
  targetElement: TJSHTMLElement;
begin
  // Find target element
  targetElement := GetTargetElement(ARequest.Target, ARequest.Element);
  
  if Assigned(targetElement) then
  begin
    // === ADICIONAR CLASSES DE TRANSIÇÃO ===
    AddCSSClasses(targetElement, 'ehtml-swapping');
    // =====================================
    
    SwapContent(targetElement, AResponse, ARequest.Swap);
    
    // === REMOVER CLASSES APÓS UM TEMPO ===
    (*
    asm
      setTimeout(function() {
        pas.TEHTML.Instance.RemoveCSSClasses(targetElement, 'ehtml-swapping');
        pas.TEHTML.Instance.AddCSSClasses(targetElement, 'ehtml-settling');
        setTimeout(function() {
          pas.TEHTML.Instance.RemoveCSSClasses(targetElement, 'ehtml-settling');
        }, 20);
      }, 0);
    end;
    *)
    // ====================================
    
    // Process any new EHTML elements in the response
    Process(targetElement);
  end
  else
    console.warn('EHTML: Target element not found:', ARequest.Target);
end;

procedure TEHTML.SwapContent(ATarget: TJSHTMLElement; AContent: string; AStrategy: TSwapStrategy);
begin
  case AStrategy of
    ssInnerHTML:
      ATarget.innerHTML := AContent;
    ssOuterHTML:
      ATarget.outerHTML := AContent;
    ssBeforeBegin:
      ATarget.insertAdjacentHTML('beforebegin', AContent);
    ssAfterBegin:
      ATarget.insertAdjacentHTML('afterbegin', AContent);
    ssBeforeEnd:
      ATarget.insertAdjacentHTML('beforeend', AContent);
    ssAfterEnd:
      ATarget.insertAdjacentHTML('afterend', AContent);
    ssDelete:
      ATarget.remove;
    ssNone:
      ; // Do nothing
  end;
end;

procedure TEHTML.Initialize;
var
  procedure procContentLoaded(event: TJSEvent);
    begin
      Process;
    end;
begin
  // Process the entire document when DOM is ready
  if document.readyState = 'loading' then
  begin
    document.addEventListener('DOMContentLoaded', @procContentLoaded);
  end
  else
    Process;

  if not Assigned(HandlerMap) then
    HandlerMap := TJSObject.new;
end;

procedure TEHTML.AddHandler(const Name: string; Handler: TProcedureRef);
begin
  HandlerMap[Name] := Handler;
end;

procedure TEHTML.Process(AElement: TJSHTMLElement = nil);
var
  elements: TJSNodeList;
  i: Integer;
  element: TJSHTMLElement;
begin
  if Assigned(AElement) then
  begin
    // Process single element
    ProcessElement(AElement);
    
    // Process child elements with EHTML attributes
    elements := AElement.querySelectorAll('[data-get], [data-post], [data-put], [data-delete], [data-patch], [data-handler]');
  end
  else
  begin
    // Process entire document
    elements := document.querySelectorAll('[data-get], [data-post], [data-put], [data-delete], [data-patch], [data-handler]');
  end;
  
  for i := 0 to elements.length - 1 do
  begin
    element := TJSHTMLElement(elements.item(i));
    ProcessElement(element);
  end;
end;

procedure TEHTML.ProcessSelector(const ASelector: string);
var
  elements: TJSNodeList;
  i: Integer;
begin
  elements := document.querySelectorAll(ASelector);
  for i := 0 to elements.length - 1 do
    ProcessElement(TJSHTMLElement(elements.item(i)));
end;

// Global functions

procedure EHTMLInit;
begin
  TEHTML.Instance.Initialize;
end;

function EHTML: TEHTML;
begin
  Result := TEHTML.Instance;
end;

procedure procInit(event: TJSEvent);
    begin
      EHTMLInit;
    end;

// Auto-initialize when the unit is loaded
initialization
  // Auto-initialize when DOM is ready
  if document.readyState = 'loading' then
  begin
    document.addEventListener('DOMContentLoaded', @procInit);
  end
  else
    EHTMLInit;

end.