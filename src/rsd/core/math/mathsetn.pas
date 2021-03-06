unit MathSetN;

{$mode objfpc}{$H+}{$interfaces corba}

interface

uses
  Classes, SysUtils, MathBasics;

type
  TIMathInteger = interface(TIMathObject)
    function Add(const x:TIMathInteger):TIMathInteger;
    function Sub(const x:TIMathInteger):TIMathInteger;
    function Mul(const x:TIMathInteger):TIMathInteger;
    function Pow(const x:TIMathInteger):TIMathInteger;
    function IsMultiple(const x:TIMathInteger):Boolean;
    function IsDivider(const x:TIMathInteger):Boolean;
    function IsPrimitif(const x:TIMathInteger):TIMathInteger;
    property AsString:String;
  end;

implementation

end.

