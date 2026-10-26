unit ClassRecordCorpus;

interface

uses System.Types;

type
  TIdentifier = Integer;
  TPointValue = record
    X, Y: Integer;
    function Sum: Integer;
  end;

  TCustomer = class(TObject)
  strict private
    FName: string;
    FPosition: System.Types.TPoint;
  protected
    procedure Changed; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetName(const Value: string); overload;
    function GetName: string;
    property Name: string read FName write SetName;
    // Members following an opaque property must remain structured.
    procedure Save; virtual;
  end;

  TCustomerClass = class of TCustomer;
  TRectangleValue = record
    Left, Top: Integer;
    Right, Bottom: Integer;
  end;

implementation

function TPointValue.Sum: Integer;
begin
  Result := X + Y;
end;

constructor TCustomer.Create;
begin
  FName := '';
  FPosition.X := 0;
  FPosition.Y := 0;
end;

destructor TCustomer.Destroy;
begin
  FName := '';
end;

procedure TCustomer.Changed;
begin
end;

procedure TCustomer.SetName(const Value: string);
begin
  FName := Value;
  Changed;
end;

function TCustomer.GetName: string;
begin
  Result := FName;
end;

procedure TCustomer.Save;
begin
  Changed;
end;

end.
