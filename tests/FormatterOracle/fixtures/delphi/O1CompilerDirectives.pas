unit O1CompilerDirectives;

{ O1 fixture: compiler directives (separate on purpose). Self-authored.
  Designed so that both the DEBUG-defined and DEBUG-undefined variants
  are complete Delphi units; not compiler-verified (see fixture manifest). }

interface

{$IFDEF DEBUG}
const
  BuildKind = 'debug';
{$ELSE}
const
  BuildKind = 'release';
{$ENDIF}

procedure Directives;

implementation

{$ifdef O1_UNDEFINED_SYMBOL}
uses
  O1DoesNotExist;
{$endif}

procedure Directives;
var
  A: Integer;
begin
  A := 0;
{$IF Defined(DEBUG)}
  A := 1;
{$ELSE}
  A := 2;
{$IFEND}
    {$IFOPT R+}
  A := A + 1;
    {$ENDIF}
  {$region 'O1 region'}
  A := A * 2;
  {$endregion}
end;

end.
