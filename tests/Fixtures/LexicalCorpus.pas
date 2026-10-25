unit LexicalCorpus;

interface

uses System.Generics.Collections;

type
  TSample<T> = class
  private
    FItems: TList<T>;
  public
    constructor Create;
    destructor Destroy; override;
    function Count: Integer;
  end;

const
  DecimalValue = 1_000_000;
  HexValue = $12_AB;
  BinaryValue = %10_10;
  RealValue = 1_2.3_4e+0_1;
  CharacterValue = #$0A;
  SeparatedCharacter = #1_0;
  TrailingDot = 1.;
  Quoted = 'It''s Delphi // { (*';
  UnicodeText = 'Grüße 世界';
  Multiline = '''
    SELECT * FROM Customers
    WHERE Department = 'R&D'
    ''';
  FiveQuotes = '''''
    Embedded ''' quotes
    ''''';
  SevenQuotes = '''''''
    Embedded ''''' quotes
    ''''''';

implementation

/// <summary>Generic corpus with all lexical categories.</summary>
{$IFDEF MSWINDOWS}
(*$WARN SYMBOL_PLATFORM OFF*)
{$ENDIF}
{ (* Mixed comment styles *) }
(* { Mixed comment styles } *)
{ (* } const CrossStyleEndsAtOuter = 1;
(* { *) const OtherStyleEndsAtOuter = 2;

constructor TSample<T>.Create;
begin
  inherited;
  FItems := TList<T>.Create;
end;

destructor TSample<T>.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TSample<T>.Count: Integer;
begin
  Result := FItems.Count;
end;

end.
