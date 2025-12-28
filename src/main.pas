program main;

{$mode objfpc}{$H+}

uses
  Web, ehtmlunit;

procedure MyHandler(Element: TJSHTMLElement);
begin
  window.alert('Handler triggered!');
end;

procedure MyHandlerWithParams(Element: TJSHTMLElement);
var
  paramInfo, paramFoo: string;
begin
  paramInfo := Element.getAttribute('data-info');
  paramFoo := Element.getAttribute('data-foo');

  document.querySelector('#handler-result').innerHTML := Element.id + ' - executed with params.<br>'+
    'Param data-info: ' + paramInfo + '<br>' +
    'Param data-foo: ' + paramFoo + '<br>';
end;

begin

  ehtml.AddHandler('myHandler', @MyHandler);
  ehtml.AddHandler('myHandlerWithParams', @MyHandlerWithParams);
  
end.