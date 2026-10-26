unit DirectiveCorpus;

interface

{$H+}
{$WARN SYMBOL_DEPRECATED OFF}

type
  TExample = class
  private
    FValue: Integer;
  public
    procedure Execute;
  end;

{$IFDEF DEBUG}
procedure DebugLog;
{$ELSE}
procedure ReleaseLog;
{$ENDIF}

implementation

procedure TExample.Execute;
begin
  FValue := 1;
end;

{$IFDEF DEBUG}
procedure DebugLog;
begin
end;
{$ELSE}
procedure ReleaseLog;
begin
end;
{$ENDIF}

end.
