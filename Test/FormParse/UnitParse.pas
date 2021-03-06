unit UnitParse;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls, ExtCtrls, CnTree, CnWizDfmParser;

type
  TParseForm = class(TForm)
    lblForm: TLabel;
    edtFile: TEdit;
    btnParse: TButton;
    dlgOpen: TOpenDialog;
    btnBrowse: TButton;
    Bevel1: TBevel;
    tvDfm: TTreeView;
    procedure btnBrowseClick(Sender: TObject);
    procedure btnParseClick(Sender: TObject);
    procedure tvDfmDblClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FTree: TCnDfmTree;
    procedure TreeSaveNode(ALeaf: TCnLeaf; ATreeNode: TTreeNode;
      var Valid: Boolean);
  public
    { Public declarations }
  end;

var
  ParseForm: TParseForm;

implementation

{$R *.DFM}

procedure TParseForm.btnBrowseClick(Sender: TObject);
begin
  if dlgOpen.Execute then
    edtFile.Text := dlgOpen.FileName;
end;

procedure TParseForm.btnParseClick(Sender: TObject);
var
  Info: TDfmInfo;
begin
  Info := TDfmInfo.Create;
  try
    if FileExists(edtFile.Text) then
    begin
      ParseDfmFile(edtFile.Text, Info);
      ShowMessage(Info.Name);
    end;
  finally
    Info.Free;
  end;

  FTree.Clear;
  if FileExists(edtFile.Text) then
    if LoadDfmFileToTree(edtFile.Text, FTree) then
    begin
      ShowMessage(IntToStr(FTree.Count));
      FTree.OnSaveANode := TreeSaveNode;
      FTree.SaveToTreeView(tvDfm);
      tvDfm.Items[0].Expand(True);
    end;
end;

procedure TParseForm.TreeSaveNode(ALeaf: TCnLeaf; ATreeNode: TTreeNode;
  var Valid: Boolean);
begin
  ATreeNode.Data := ALeaf;
  ATreeNode.Text := ALeaf.Text + ': ' + TCnDfmLeaf(ALeaf).ElementClass;
  Valid := True;
end;

procedure TParseForm.tvDfmDblClick(Sender: TObject);
var
  Leaf: TCnDfmLeaf;
begin
  if tvDfm.Selected <> nil then
  begin
    Leaf := TCnDfmLeaf(tvDfm.Selected.Data);
    ShowMessage(Leaf.Properties.Text);
  end;
end;

procedure TParseForm.FormCreate(Sender: TObject);
begin
  FTree := TCnDfmTree.Create;
end;

procedure TParseForm.FormDestroy(Sender: TObject);
begin
  FTree.Free;
end;

end.
