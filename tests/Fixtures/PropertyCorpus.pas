unit PropertyCorpus;

interface

type
  TPropertyExample = class
  private
    FName: string;
    FCount: Integer;
    FEnabled: Boolean;
    function GetItem(Index: Integer): string;
    procedure SetItem(Index: Integer; const Value: string);
    function GetCoordinate(Index: Integer): Integer;
    procedure SetCoordinate(Index: Integer; Value: Integer);
    function ShouldStore: Boolean;
  protected
    property Hidden: Integer read FCount;
  public
    property Name: string read FName write FName;
    property ReadOnly: Integer read FCount;
    property WriteOnly: Integer write FCount;
    property Count: Integer read FCount write FCount default -1;
    property Enabled: Boolean read FEnabled write FEnabled stored False default True;
    property StoredCount: Integer read FCount stored ShouldStore nodefault;
    property Left: Integer index 0 read GetCoordinate write SetCoordinate;
    property Right: Integer index 2 read GetCoordinate write SetCoordinate;
    property Items[Index: Integer]: string read GetItem write SetItem; default;
  end;

  TPropertyDescendant = class(TPropertyExample)
  public
    property Hidden;
    property Count default 0;
    property Enabled stored True;
  end;

implementation

function TPropertyExample.GetItem(Index: Integer): string;
begin
  Result := FName;
end;

procedure TPropertyExample.SetItem(Index: Integer; const Value: string);
begin
  FName := Value;
end;

function TPropertyExample.GetCoordinate(Index: Integer): Integer;
begin
  Result := FCount;
end;

procedure TPropertyExample.SetCoordinate(Index: Integer; Value: Integer);
begin
  FCount := Value;
end;

function TPropertyExample.ShouldStore: Boolean;
begin
  Result := True;
end;

end.
