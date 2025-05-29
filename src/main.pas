program main;

{$mode objfpc}{$H+}

uses
  Web, ehtml;

procedure MyHandler(el: TJSHTMLElement; data: TJSFormData);
begin
  window.alert('Handler acionado!');
end;

begin
  ehtml.InitEHTML;
  ehtml.AddHandler('meuHandler', @MyHandler);
end.