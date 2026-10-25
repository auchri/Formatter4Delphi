unit DelphiFormatter.Core.Diagnostics;

interface

uses
  DelphiFormatter.Core.Spans;

type
  TDiagnosticSeverity = (dsInfo, dsWarning, dsError);

  TDiagnostic = record
    Code: string;
    Message: string;
    Severity: TDiagnosticSeverity;
    Span: TSourceSpan;
    constructor Create(const ACode, AMessage: string;
      ASeverity: TDiagnosticSeverity; const ASpan: TSourceSpan);
  end;

implementation

constructor TDiagnostic.Create(const ACode, AMessage: string;
  ASeverity: TDiagnosticSeverity; const ASpan: TSourceSpan);
begin
  Code := ACode;
  Message := AMessage;
  Severity := ASeverity;
  Span := ASpan;
end;

end.
