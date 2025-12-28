program main;

{$mode objfpc}{$H+}

uses
  Web, ehtmlunit;

procedure MyHandler;
begin
  window.alert('Handler acionado!');
end;

begin
  // ehtml.InitEHTML;
  ehtml.AddHandler('meuHandler', @MyHandler);
  WriteLn('EHTML Initialized with custom handler.');
end.