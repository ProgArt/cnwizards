{******************************************************************************}
{                       CnPack For Delphi/C++Builder                           }
{                     中国人自己的开放源码第三方开发包                         }
{                   (C)Copyright 2001-2019 CnPack 开发组                       }
{                   ------------------------------------                       }
{                                                                              }
{            本开发包是开源的自由软件，您可以遵照 CnPack 的发布协议来修        }
{        改和重新发布这一程序。                                                }
{                                                                              }
{            发布这一开发包的目的是希望它有用，但没有任何担保。甚至没有        }
{        适合特定目的而隐含的担保。更详细的情况请参阅 CnPack 发布协议。        }
{                                                                              }
{            您应该已经和开发包一起收到一份 CnPack 发布协议的副本。如果        }
{        还没有，可访问我们的网站：                                            }
{                                                                              }
{            网站地址：http://www.cnpack.org                                   }
{            电子邮件：master@cnpack.org                                       }
{                                                                              }
{******************************************************************************}

unit CnWizDfmParser;
{ |<PRE>
================================================================================
* 软件名称：CnPack IDE 专家包
* 单元名称：分析 DFM 文件信息
* 单元作者：周劲羽 (zjy@cnpack.org)
* 备    注：
* 开发平台：PWinXP SP2 + Delphi 7.1
* 兼容测试：PWin9X/2000/XP + Delphi 5/6/7 + C++Builder 5/6
* 本 地 化：该单元中的字符串支持本地化处理方式
* 修改记录：2012.09.19 by shenloqi
*               移植到Delphi XE3
*           2005.03.23 V1.0
*               创建单元
================================================================================
|</PRE>}

interface

{$I CnWizards.inc}

uses
  Windows, SysUtils, Classes, CnCommon, CnTree,
{$IFDEF COMPILER6_UP}
  Variants, RTLConsts,
{$ELSE}
  Consts,
{$ENDIF}
  TypInfo;

type
  TDfmFormat = (dfUnknown, dfText, dfBinary);
  TDfmKind = (dkObject, dkInherited, dkInline);

  TDfmInfo = class(TPersistent)
  private
    FFormat: TDfmFormat;
    FKind: TDfmKind;
    FName: string;
    FFormClass: string;
    FCaption: string;
    FLeft: Integer;
    FTop: Integer;
    FWidth: Integer;
    FHeight: Integer;
  published
    property Top: Integer read FTop write FTop;
    property Width: Integer read FWidth write FWidth;
    property Name: string read FName write FName;
    property Left: Integer read FLeft write FLeft;
    property Kind: TDfmKind read FKind write FKind;
    property Height: Integer read FHeight write FHeight;
    property Format: TDfmFormat read FFormat write FFormat;
    property FormClass: string read FFormClass write FFormClass;
    property Caption: string read FCaption write FCaption;
  end;

  TCnDfmLeaf = class(TCnLeaf)
  {* 代表 DFM 中的一个组件}
  private
    FElementClass: string;
    FElementKind: TDfmKind;
    FProperties: TStrings;
  public
    constructor Create(ATree: TCnTree); override;
    {* 构造方法 }
    destructor Destroy; override;
    {* 析构方法 }

    // 用父类的 Text 属性当作 Name
    property ElementClass: string read FElementClass write FElementClass;
    property ElementKind: TDfmKind read FElementKind write FElementKind;
    property Properties: TStrings read FProperties;
  end;

  TCnDfmTree = class(TCnTree)
  private
    FDfmFormat: TDfmFormat;
    FDfmKind: TDfmKind;
  public
    constructor Create;
    destructor Destroy; override;

    property DfmKind: TDfmKind read FDfmKind write FDfmKind;
    property DfmFormat: TDfmFormat read FDfmFormat write FDfmFormat;
  end;

const
  SDfmFormats: array[TDfmFormat] of string = ('Unknown', 'Text', 'Binary');
  SDfmKinds: array[TDfmKind] of string = ('Object', 'Inherited', 'Inline');

function ParseDfmStream(Stream: TStream; Info: TDfmInfo): Boolean;
{* 简单解析 DFM 流读出最外层 Container 的信息}

function ParseDfmFile(const FileName: string; Info: TDfmInfo): Boolean;
{* 简单解析 DFM 文件读出最外层 Container 的信息}

function LoadDfmStreamToTree(Stream: TStream; Tree: TCnDfmTree): Boolean;
{* 将 DFM 流解析成树}

function LoadDfmFileToTree(const FileName: string; Tree: TCnDfmTree): Boolean;
{* 将 DFM 文件解析成树}

implementation

const
  csPropCount = 5;
  CRLF = #13#10;
  FILER_SIGNATURE: array[1..4] of AnsiChar = ('T', 'P', 'F', '0');

{$IFNDEF COMPILER6_UP}
function CombineString(Parser: TParser): string;
begin
  Result := Parser.TokenString;
  while Parser.NextToken = '+' do
  begin
    Parser.NextToken;
    Parser.CheckToken(toString);
    Result := Result + Parser.TokenString;
  end;
end;
{$ENDIF}

function CombineWideString(Parser: TParser): WideString;
begin
  Result := Parser.TokenWideString;
  while Parser.NextToken = '+' do
  begin
    Parser.NextToken;
    if not CharInSet(Parser.Token, [toString, toWString]) then
      Parser.CheckToken(toString);
    Result := Result + Parser.TokenWideString;
  end;
end;

function ParseTextOrderModifier(Parser: TParser): Integer;
begin
  Result := -1;
  if Parser.Token = '[' then
  begin
    Parser.NextToken;
    Parser.CheckToken(toInteger);
    Result := Parser.TokenInt;
    Parser.NextToken;
    Parser.CheckToken(']');
    Parser.NextToken;
  end;
end;

function ParseTextPropertyValue(Parser: TParser): string; forward;

procedure ParseTextHeaderToLeaf(Parser: TParser; IsInherited, IsInline: Boolean;
  Leaf: TCnDfmLeaf); forward;

procedure ParseTextPropertyToLeaf(Parser: TParser; Leaf: TCnDfmLeaf);
var
  PropName: string;
  PropValue: string;
begin
  Parser.CheckToken(toSymbol);
  PropName := Parser.TokenString;
  Parser.NextToken;
  while Parser.Token = '.' do
  begin
    Parser.NextToken;
    Parser.CheckToken(toSymbol);
    PropName := PropName + '.' + Parser.TokenString;
    Parser.NextToken;
  end;

  Parser.CheckToken('=');
  Parser.NextToken;
  PropValue := ParseTextPropertyValue(Parser);

  Leaf.Properties.Add(PropName + '=' + PropValue);
end;

function ParseTextPropertyValue(Parser: TParser): string;
begin
  Result := '';
{$IFDEF COMPILER6_UP}
  if CharInSet(Parser.Token, [toString, toWString]) then
    Result := CombineWideString(Parser)
{$ELSE}
  if Parser.Token = toString then
    Result := CombineString(Parser)
  else if Parser.Token = toWString then
    Result := CombineWideString(Parser)
{$ENDIF}
  else
  begin
    case Parser.Token of
      toSymbol:
        Result := Parser.TokenComponentIdent;
      toInteger:
        Result := IntToStr(Parser.TokenInt);
      toFloat:
        Result := FloatToStr(Parser.TokenFloat);
      '[':
        begin
          Parser.NextToken;
          if Parser.Token <> ']' then
            while True do
            begin
              if Parser.Token <> toInteger then
                Parser.CheckToken(toSymbol);
              if Parser.NextToken = ']' then Break;
              Parser.CheckToken(',');
              Parser.NextToken;
            end;
        end;
      '(':  // 字符串列表
        begin
          Result := Parser.TokenString;
          Parser.NextToken;
          while Parser.Token <> ')' do
          begin
            Result := Result + Parser.TokenString;
            Parser.NextToken;
          end;
          Result := Result + ')';
        end;
      '{':  // 二进制数据
        begin
          Result := Parser.TokenString;
          Parser.NextToken;
          while Parser.Token <> '}' do
          begin
            Result := Result + Parser.TokenString;
            Parser.NextToken;
          end;
          Result := Result + '}';
        end;
      '<':  // TODO: Collection 的 Items 需要分割处理
        begin
          Result := Parser.TokenString;
          Parser.NextToken;
          while Parser.Token <> '>' do
          begin
            Result := Result + Parser.TokenString;
            Parser.NextToken;
          end;
          Result := Result + '>';
        end;
    else
      Parser.Error(SInvalidProperty);
    end;
    Parser.NextToken;
  end;
end;

// 递归解析 Object。进入调用时 Parser 停留在 object，Leaf 是个新建的
procedure ParseTextObjectToLeaf(Parser: TParser; Tree: TCnDfmTree; Leaf: TCnDfmLeaf);
var
  InheritedObject: Boolean;
  InlineObject: Boolean;
  Child: TCnDfmLeaf;
begin
  InheritedObject := False;
  InlineObject := False;
  if Parser.TokenSymbolIs('INHERITED') then
  begin
    InheritedObject := True;
    Leaf.ElementKind := dkInherited;
  end
  else if Parser.TokenSymbolIs('INLINE') then
  begin
    InlineObject := True;
    Leaf.ElementKind := dkInline;
  end
  else
  begin
    Parser.CheckTokenSymbol('OBJECT');
    Leaf.ElementKind := dkObject;
  end;

  Parser.NextToken;
  ParseTextHeaderToLeaf(Parser, InheritedObject, InlineObject, Leaf);

  while not Parser.TokenSymbolIs('END') and
    not Parser.TokenSymbolIs('OBJECT') and
    not Parser.TokenSymbolIs('INHERITED') and
    not Parser.TokenSymbolIs('INLINE') do
    ParseTextPropertyToLeaf(Parser, Leaf);

  while Parser.TokenSymbolIs('OBJECT') or
    Parser.TokenSymbolIs('INHERITED') or
    Parser.TokenSymbolIs('INLINE') do
  begin
    Child := Tree.AddChild(Leaf) as TCnDfmLeaf;
    ParseTextObjectToLeaf(Parser, Tree, Child);
  end;
  Parser.NextToken; // 过 end
end;

procedure ParseTextHeaderToLeaf(Parser: TParser; IsInherited, IsInline: Boolean; Leaf: TCnDfmLeaf);
begin
  Parser.CheckToken(toSymbol);
  Leaf.ElementClass := Parser.TokenString;
  Leaf.Text := '';
  if Parser.NextToken = ':' then
  begin
    Parser.NextToken;
    Parser.CheckToken(toSymbol);
    Leaf.Text := Leaf.ElementClass;
    Leaf.ElementClass := Parser.TokenString;
    Parser.NextToken;
  end;
  ParseTextOrderModifier(Parser);
end;

// 简单解析 Text 格式的 Dfm 拿到 Info
function ParseTextDfmStream(Stream: TStream; Info: TDfmInfo): Boolean;
var
  SaveSeparator: Char;
  Parser: TParser;
  PropCount: Integer;

  procedure ParseHeader(IsInherited, IsInline: Boolean);
  begin
    Parser.CheckToken(toSymbol);
    Info.FormClass := Parser.TokenString;
    Info.Name := '';
    if Parser.NextToken = ':' then
    begin
      Parser.NextToken;
      Parser.CheckToken(toSymbol);
      Info.Name := Info.FormClass;
      Info.FormClass := Parser.TokenString;
      Parser.NextToken;
    end;
    ParseTextOrderModifier(Parser);
  end;

  procedure ParseProperty(IsForm: Boolean); forward;

  function ParseValue: Variant;
  begin
    Result := Null;
  {$IFDEF COMPILER6_UP}
    if CharInSet(Parser.Token, [toString, toWString]) then
      Result := CombineWideString(Parser)
  {$ELSE}
    if Parser.Token = toString then
      Result := CombineString(Parser)
    else if Parser.Token = toWString then
      Result := CombineWideString(Parser)
  {$ENDIF}
    else
    begin
      case Parser.Token of
        toSymbol:
          Result := Parser.TokenComponentIdent;
        toInteger:
        {$IFDEF COMPILER6_UP}
          Result := Parser.TokenInt;
        {$ELSE}
          Result := Integer(Parser.TokenInt);
        {$ENDIF}
        toFloat:
          Result := Parser.TokenFloat;
        '[':
          begin
            Parser.NextToken;
            if Parser.Token <> ']' then
              while True do
              begin
                if Parser.Token <> toInteger then
                  Parser.CheckToken(toSymbol);
                if Parser.NextToken = ']' then Break;
                Parser.CheckToken(',');
                Parser.NextToken;
              end;
          end;
        '(':
          begin
            Parser.NextToken;
            while Parser.Token <> ')' do ParseValue;
          end;
        '{':
          Parser.HexToBinary(Stream);
        '<':
          begin
            Parser.NextToken;
            while Parser.Token <> '>' do
            begin
              Parser.CheckTokenSymbol('item');
              Parser.NextToken;
              ParseTextOrderModifier(Parser);
              while not Parser.TokenSymbolIs('end') do ParseProperty(False);
              Parser.NextToken;
            end;
          end;
      else
        Parser.Error(SInvalidProperty);
      end;
      Parser.NextToken;
    end;
  end;

  procedure ParseProperty(IsForm: Boolean);
  var
    PropName: string;
    PropValue: Variant;
  begin
    Parser.CheckToken(toSymbol);
    PropName := Parser.TokenString;
    Parser.NextToken;
    while Parser.Token = '.' do
    begin
      Parser.NextToken;
      Parser.CheckToken(toSymbol);
      PropName := PropName + '.' + Parser.TokenString;
      Parser.NextToken;
    end;

    Parser.CheckToken('=');
    Parser.NextToken;
    PropValue := ParseValue;

    if IsForm then
    begin
      Inc(PropCount);
      if SameText(PropName, 'Left') then
        Info.Left := PropValue
      else if SameText(PropName, 'Top') then
        Info.Top := PropValue
      else if SameText(PropName, 'Width') or SameText(PropName, 'ClientWidth') then
        Info.Width := PropValue
      else if SameText(PropName, 'Height') or SameText(PropName, 'ClientHeight') then
        Info.Height := PropValue
      else if SameText(PropName, 'Caption') then
        Info.Caption := PropValue
      else
        Dec(PropCount);
    end;
  end;

  procedure ParseObject;
  var
    InheritedObject: Boolean;
    InlineObject: Boolean;
  begin
    InheritedObject := False;
    InlineObject := False;
    if Parser.TokenSymbolIs('INHERITED') then
    begin
      InheritedObject := True;
      Info.Kind := dkInherited;
    end
    else if Parser.TokenSymbolIs('INLINE') then
    begin
      InlineObject := True;
      Info.Kind := dkInline;
    end
    else
    begin
      Parser.CheckTokenSymbol('OBJECT');
      Info.Kind := dkObject;
    end;
    Parser.NextToken;
    ParseHeader(InheritedObject, InlineObject);
    while (PropCount < csPropCount) and
      not Parser.TokenSymbolIs('END') and
      not Parser.TokenSymbolIs('OBJECT') and
      not Parser.TokenSymbolIs('INHERITED') and
      not Parser.TokenSymbolIs('INLINE') do
      ParseProperty(True);
  end;

begin
  try
    Parser := TParser.Create(Stream);
    SaveSeparator := {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator;
    {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := '.';
    try
      PropCount := 0;
      ParseObject;
      Result := True;
    finally
      {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := SaveSeparator;
      Parser.Free;
    end;
  except
    Result := False;
  end;
end;

// 简单解析二进制格式的 Dfm 拿到 Info
function ParseBinaryDfmStream(Stream: TStream; Info: TDfmInfo): Boolean;
var
  SaveSeparator: Char;
  Reader: TReader;
  PropName: string;
  PropCount: Integer;

  procedure ParseHeader;
  var
    FormClass: string;
    Flags: TFilerFlags;
    Position: Integer;
  begin
    Reader.ReadPrefix(Flags, Position);
    Info.FormClass := Reader.ReadStr;
    Info.Name := Reader.ReadStr;
    if Info.Name = '' then
      Info.Name := FormClass; 
  end;

  procedure ParseBinary;
  const
    BytesPerLine = 32;
  var
    I: Integer;
    Count: Longint;
    Buffer: array[0..BytesPerLine - 1] of Char;
  begin
    Reader.ReadValue;
    Reader.Read(Count, SizeOf(Count));
    while Count > 0 do
    begin
      if Count >= 32 then I := 32 else I := Count;
      Reader.Read(Buffer, I);
      Dec(Count, I);
    end;
  end;

  procedure ParseProperty(IsForm: Boolean); forward;

  function ParseValue: Variant;
  const
    LineLength = 64;
  var
    S: string;
  begin
    Result := Null;
    case Reader.NextValue of
      vaList:
        begin
          Reader.ReadValue;
          while not Reader.EndOfList do
            ParseValue;
          Reader.ReadListEnd;
        end;
      vaInt8, vaInt16, vaInt32:
        Result := Reader.ReadInteger;
      vaExtended:
        Result := Reader.ReadFloat;
      vaSingle:
        Result := Reader.ReadSingle;
      vaCurrency:
        Result := Reader.ReadCurrency;
      vaDate:
        Result := Reader.ReadDate;
      vaWString{$IFDEF COMPILER6_UP}, vaUTF8String{$ENDIF}:
        Result := Reader.ReadWideString;
      vaString, vaLString:
        Result := Reader.ReadString;
      vaIdent, vaFalse, vaTrue, vaNil, vaNull:
        Result := Reader.ReadIdent;
      vaBinary:
        ParseBinary;
      vaSet:
        begin
          Reader.ReadValue;
          while True do
          begin
            S := Reader.ReadStr;
            if S = '' then Break;
          end;
        end;
      vaCollection:
        begin
          Reader.ReadValue;
          while not Reader.EndOfList do
          begin
            if Reader.NextValue in [vaInt8, vaInt16, vaInt32] then
            begin
              ParseValue;
            end;
            Reader.CheckValue(vaList);
            while not Reader.EndOfList do ParseProperty(False);
            Reader.ReadListEnd;
          end;
          Reader.ReadListEnd;
        end;
      vaInt64:
      {$IFDEF COMPILER6_UP}
        Result := Reader.ReadInt64;
      {$ELSE}
        Result := Integer(Reader.ReadInt64);
      {$ENDIF}
    else
      raise EReadError.CreateResFmt(@sPropertyException,
        [Info.Name, DotSep, PropName, IntToStr(Ord(Reader.NextValue))]);
    end;
  end;

  procedure ParseProperty(IsForm: Boolean);
  var
    PropValue: Variant;
  begin
    PropName := Reader.ReadStr;
    PropValue := ParseValue;

    if IsForm then
    begin
      Inc(PropCount);
      if SameText(PropName, 'Left') then
        Info.Left := PropValue
      else if SameText(PropName, 'Top') then
        Info.Top := PropValue
      else if SameText(PropName, 'Width') then
        Info.Width := PropValue
      else if SameText(PropName, 'Height') then
        Info.Height := PropValue
      else if SameText(PropName, 'Caption') then
        Info.Caption := PropValue
      else
        Dec(PropCount);
    end;
  end;

  procedure ParseObject;
  begin
    ParseHeader;
    while (PropCount < csPropCount) and not Reader.EndOfList do
      ParseProperty(True);
  end;

begin
  try
    Reader := TReader.Create(Stream, 4096);
    SaveSeparator := {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator;
    {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := '.';
    try
      PropCount := 0;
      Reader.ReadSignature;
      ParseObject;
      Result := True;
    finally
      {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := SaveSeparator;
      Reader.Free;
    end;
  except
    Result := False;
  end;
end;

function ParseDfmStream(Stream: TStream; Info: TDfmInfo): Boolean;
var
  Pos: Integer;
  Signature: Integer;
  BOM: array[1..3] of AnsiChar;
begin
  Pos := Stream.Position;
  Signature := 0;
  Stream.Read(Signature, SizeOf(Signature));
  Stream.Position := Pos;
  if AnsiChar(Signature) in ['o','O','i','I',' ',#13,#11,#9] then
  begin
    Info.Format := dfText;
    Result := ParseTextDfmStream(Stream, Info);
  end
  else
  begin
    Pos := Stream.Position;
    Signature := 0;
    Stream.Read(BOM, SizeOf(BOM));
    Stream.Position := Pos;

    if ((BOM[1] = #$FF) and (BOM[2] = #$FE)) or // UTF8/UTF 16
      ((BOM[1] = #$EF) and (BOM[2] = #$BB) and (BOM[3] = #$BF)) then
    begin
      Info.Format := dfText;
      Result := ParseTextDfmStream(Stream, Info); // Only ANSI yet
    end
    else
    begin
      Stream.ReadResHeader;
      Pos := Stream.Position;
      Signature := 0;
      Stream.Read(Signature, SizeOf(Signature));
      Stream.Position := Pos;
      if Signature = Integer(FILER_SIGNATURE) then
      begin
        Info.Format := dfBinary;
        Result := ParseBinaryDfmStream(Stream, Info);
      end
      else
      begin
        Info.Format := dfUnknown;
        Result := False;
      end;
    end;
  end;
end;

function ParseDfmFile(const FileName: string; Info: TDfmInfo): Boolean;
var
  Stream: TFileStream;
begin
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := ParseDfmStream(Stream, Info);
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadTextDfmStreamToTree(Stream: TStream; Tree: TCnDfmTree): Boolean;
var
  SaveSeparator: Char;
  Parser: TParser;
  StartLeaf: TCnDfmLeaf;
begin
  Parser := TParser.Create(Stream);
  try
    SaveSeparator := {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator;
    {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := '.';
    try
      StartLeaf := Tree.AddChild(Tree.Root) as TCnDfmLeaf;
      ParseTextObjectToLeaf(Parser, Tree, StartLeaf as TCnDfmLeaf);
      Result := True;
    finally
      {$IFDEF DELPHIXE3_UP}FormatSettings.{$ENDIF}DecimalSeparator := SaveSeparator;
      Parser.Free;
    end;
  except
    Result := False;
  end;
end;

function LoadBinaryDfmStreamToTree(Stream: TStream; Tree: TCnDfmTree): Boolean;
begin
  Result := False;
end;

function LoadDfmStreamToTree(Stream: TStream; Tree: TCnDfmTree): Boolean;
var
  Pos: Integer;
  Signature: Integer;
  BOM: array[1..3] of AnsiChar;
begin
  Pos := Stream.Position;
  Signature := 0;
  Stream.Read(Signature, SizeOf(Signature));
  Stream.Position := Pos;
  if AnsiChar(Signature) in ['o','O','i','I',' ',#13,#11,#9] then
  begin
    Tree.DfmFormat := dfText;
    Result := LoadTextDfmStreamToTree(Stream, Tree);
  end
  else
  begin
    Pos := Stream.Position;
    Signature := 0;
    Stream.Read(BOM, SizeOf(BOM));
    Stream.Position := Pos;

    if ((BOM[1] = #$FF) and (BOM[2] = #$FE)) or // UTF8/UTF 16
      ((BOM[1] = #$EF) and (BOM[2] = #$BB) and (BOM[3] = #$BF)) then
    begin
      Tree.DfmFormat := dfText;
      Result := LoadTextDfmStreamToTree(Stream, Tree); // Only ANSI yet
    end
    else
    begin
      Stream.ReadResHeader;
      Pos := Stream.Position;
      Signature := 0;
      Stream.Read(Signature, SizeOf(Signature));
      Stream.Position := Pos;
      if Signature = Integer(FILER_SIGNATURE) then
      begin
        Tree.DfmFormat := dfBinary;
        Result := LoadBinaryDfmStreamToTree(Stream, Tree);
      end
      else
      begin
        Tree.DfmFormat := dfUnknown;
        Result := False;
      end;
    end;
  end;
end;

function LoadDfmFileToTree(const FileName: string; Tree: TCnDfmTree): Boolean;
var
  Stream: TFileStream;
begin
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Result := LoadDfmStreamToTree(Stream, Tree);
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;
end;

{ TCnDfmTree }

constructor TCnDfmTree.Create;
begin
  inherited Create(TCnDfmLeaf);
end;

destructor TCnDfmTree.Destroy;
begin

  inherited;
end;

{ TCnDfmLeaf }

constructor TCnDfmLeaf.Create(ATree: TCnTree);
begin
  inherited;
  FProperties := TStringList.Create;
end;

destructor TCnDfmLeaf.Destroy;
begin
  FProperties.Free;
  inherited;
end;

end.
