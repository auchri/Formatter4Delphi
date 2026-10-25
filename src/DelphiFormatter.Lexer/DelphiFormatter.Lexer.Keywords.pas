unit DelphiFormatter.Lexer.Keywords;

interface

function IsReservedWord(const Source: string; StartOffset, Count: Integer): Boolean;

implementation

const
  // Embarcadero Athens: Fundamental Syntactic Elements (Delphi).
  // Context-sensitive declaration directives are intentionally absent.
  ReservedWords: array[0..65] of string = (
    'and', 'array', 'as', 'asm', 'at', 'begin', 'case', 'class', 'const',
    'constructor', 'destructor', 'dispinterface', 'div', 'do', 'downto',
    'else', 'end', 'except', 'exports', 'file', 'finalization', 'finally',
    'for', 'function', 'goto', 'if', 'implementation', 'in', 'inherited',
    'initialization', 'inline', 'interface', 'is', 'label', 'library',
    'mod', 'nil', 'not', 'object', 'of', 'on', 'or', 'packed', 'procedure',
    'program', 'property', 'raise', 'record', 'repeat', 'resourcestring',
    'set', 'shl', 'shr', 'string', 'then', 'threadvar', 'to', 'try', 'type',
    'unit', 'until', 'uses', 'var', 'while', 'with', 'xor');

function IsReservedWord(const Source: string; StartOffset, Count: Integer): Boolean;
var
  WordIndex, I: Integer;
  C: Char;
  Matches: Boolean;
begin
  Result := False;
  if (StartOffset < 0) or (Count <= 0) or (StartOffset > Length(Source)) then
    Exit;
  if Count > Length(Source) - StartOffset then
    Exit;
  for WordIndex := Low(ReservedWords) to High(ReservedWords) do
  begin
    if Length(ReservedWords[WordIndex]) <> Count then
      Continue;
    Matches := True;
    for I := 1 to Count do
    begin
      C := Source[StartOffset + I];
      if (C >= 'A') and (C <= 'Z') then
        C := Char(Ord(C) + Ord('a') - Ord('A'));
      if C <> ReservedWords[WordIndex][I] then
      begin
        Matches := False;
        Break;
      end;
    end;
    if Matches then
      Exit(True);
  end;
end;

end.
