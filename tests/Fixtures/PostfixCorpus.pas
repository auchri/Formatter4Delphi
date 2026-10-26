unit PostfixCorpus;

interface

uses System.SysUtils;

type
  TCustomer = class
  public
    Name: string;
    Value: Integer;
    &Property: Integer;
    Items: array[0..3] of TCustomer;
    procedure Save;
    procedure SetValue(NewValue: Integer);
    function GetAddress: TCustomer;
  end;
  PNode = ^TNode;
  PPNode = ^PNode;
  TNode = record
    Value: Integer;
    Next: PNode;
  end;
  TMatrix = array[0..3, 0..3] of Integer;

procedure Exercise(Customer: TCustomer; P: PNode; PP: PPNode; var Matrix: TMatrix);

implementation

procedure TCustomer.Save;
begin
  Name := System.SysUtils.IntToStr(Value);
end;

procedure TCustomer.SetValue(NewValue: Integer);
begin
  Value := NewValue;
end;

function TCustomer.GetAddress: TCustomer;
begin
  Result := Items[0];
end;

function GetObject(Customer: TCustomer): TCustomer;
begin
  Result := Customer;
end;

procedure Exercise(Customer: TCustomer; P: PNode; PP: PPNode; var Matrix: TMatrix);
var Row, Column: Integer;
begin
  Row := 0;
  Column := 1;
  Customer.Name := 'Max';
  Customer.&Property := 1;
  Customer.&Property := 2;
  Customer.Items[Row].Name := 'Graz';
  Customer.Items[Row].Value := -Matrix[Row, Column];
  Matrix[Row, Column] := Customer.Value + Customer.Items[0].Value * 2;
  Matrix[Row][Column] := Matrix(.Row, Column.);
  Matrix[Row, Column.) := Matrix(.Row, Column];
  P^.Value := Matrix[Row, Column];
  P^.Next^.Value := P^.Value;
  PP^^.Value := 42;
  P^ := PP^^;
  GetObject(Customer).Name := Customer.GetAddress().Name;
  Customer.GetAddress().Items[0].Name := 'Address';
  Customer.Items[Row].SetValue(Matrix[Row, Column]);
  Customer.Save;
  Customer.Items[Row].Save;
  if Customer.Value > 0 then Customer.Save else Customer.Items[0].Save;
end;

end.
