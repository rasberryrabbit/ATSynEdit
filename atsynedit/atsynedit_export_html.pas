{
Copyright (C) Alexey Torgashin, uvviewsoft.com
License: MPL 2.0 or LGPL
}
unit ATSynEdit_Export_HTML;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, StrUtils,
  ATSynEdit;

procedure EditorExportToHTML(Ed: TATSynEdit;
  AOutput: TStringList;
  APosBegin, APosEnd: TPoint;
  APageTitle, AFontName: string;
  AFontSize: integer; AWithNumbers: boolean;
  AColorBg, AColorNumbers: TColor);

implementation

uses
  Math,
  ATStrings,
  ATSynEdit_LineParts,
  ATStringProc_HtmlColor;

{
procedure DoCssStyle(AColorFont, AColorBg, AColorFontDef, AColorBgDef: TColor;
  out StyleName, StyleText: string);
var
  NameF, TextF, NameBg, TextBg: string;
begin
  if AColorFont<>AColorFontDef then
  begin
    NameF:= TATHtmlColorParserA.ColorToHtmlString(AColorFont);
    TextF:= 'color: '+NameF+'; ';
    Delete(NameF, 1, 1);
  end
  else
  begin
    NameF:= '';
    TextF:= '';
  end;

  if AColorBg<>AColorBgDef then
  begin
    NameBg:= TATHtmlColorParserA.ColorToHtmlString(AColorBg);
    TextBg:= 'background: '+NameBg+'; ';
    Delete(NameBg, 1, 1);
  end
  else
  begin
    NameBg:= '';
    TextBg:= '';
  end;

  StyleName:= '_'+NameF;
  if NameBg<>'' then
    StyleName+= '_'+NameBg;
  StyleText:= '    .'+StyleName+' {'+TextF+TextBg+'}';
end;
}

function EditorIsEmpty(Ed: TATSynEdit): boolean;
var
  Str: TATStrings;
begin
  Str:= Ed.Strings;
  Result:=
    (Str.Count=0) or ((Str.Count=1) and (Str.LinesLen[0]=0));
end;

function _IsSpaces(const S: string): boolean;
var
  i: integer;
begin
  for i:= 1 to Length(S) do
    if S[i]<>' ' then exit(false);
  Result:= true;
end;

procedure _AddPreToStrings(L: TStringList);
begin
  if L.Count>0 then
  begin
    L[0]:= '<pre><code>'+L[0];
    L[L.Count-1]:= L[L.Count-1]+'</code></pre>';
  end;
end;

procedure _EscapeSpecChars(var S: string);
begin
  S:= StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  S:= StringReplace(S, '<', '&lt;', [rfReplaceAll]);
  S:= StringReplace(S, '>', '&gt;', [rfReplaceAll]);
end;

procedure EditorExportToHTML(Ed: TATSynEdit;
  AOutput: TStringList;
  APosBegin, APosEnd: TPoint;
  APageTitle, AFontName: string;
  AFontSize: integer; AWithNumbers: boolean;
  AColorBg, AColorNumbers: TColor);
var
  St: TATStrings;
  ListLines, ListNums: TStringList;
  Parts: TATLineParts;
  PPart: ^TATLinePart;
  NColorFont: TColor;
  NColorAfter: TColor;
  NeedStyleFont, NeedStyleBg, NeedStyle: boolean;
  S, StrText: string;
  iLine, iPart: integer;
begin
  St:= Ed.Strings;
  if EditorIsEmpty(Ed) then exit;

  NColorFont:= clNone;
  FillChar(Parts{%H-}, Sizeof(Parts), 0);

  ListLines:= TStringList.Create;
  if AWithNumbers then
    ListNums:= TStringList.Create
  else
    ListNums:= nil;

  try
    if AWithNumbers then
    begin
      for iLine:= 0 to St.Count-1 do
        ListNums.Add(IntToStr(iLine+1)+'&nbsp;');
      _AddPreToStrings(ListNums);
    end;

    for iLine:= APosBegin.Y to Min(St.Count-1, APosEnd.Y) do
    begin
      S:= '';
      if not Ed.DoCalcLineHiliteEx(iLine, Parts, AColorBG, NColorAfter) then break;
      for iPart:= 0 to High(Parts) do
      begin
        PPart:= @Parts[iPart];
        if PPart^.Len=0 then Break;

        if (iLine=APosBegin.Y) and (PPart^.Offset<APosBegin.X) then Continue;
        if (iLine=APosEnd.Y) and (PPart^.Offset>=APosEnd.X) then Break;

        NeedStyleFont:= PPart^.ColorFont<>NColorFont;
        NeedStyleBg:= PPart^.ColorBG<>AColorBG;
        NeedStyle:= NeedStyleFont or NeedStyleBg;

        StrText:= St.LineSub(iLine, PPart^.Offset+1, PPart^.Len);
        _EscapeSpecChars(StrText);

        if _IsSpaces(StrText) and not NeedStyleBg then
        begin
          S+= StrText;
          Continue;
        end;

        if (PPart^.FontStyles and afsFontBold)<>0 then S+= '<b>';
        if (PPart^.FontStyles and afsFontItalic)<>0  then S+= '<i>';
        if (PPart^.FontStyles and afsFontCrossed)<>0 then S+= '<s>';

        if NeedStyle then
        begin
          S+= '<span style="';
          if NeedStyleFont then
            S+= 'color:' + TATHtmlColorParserA.ColorToHtmlString(PPart^.ColorFont) + ';';
          if NeedStyleBg then
            S+= 'background:' + TATHtmlColorParserA.ColorToHtmlString(PPart^.ColorBG) + ';';
          S+= '">';
        end;

        S+= StrText;
        if NeedStyle then
          S+= '</span>';

        if (PPart^.FontStyles and afsFontCrossed)<>0  then S+= '</s>';
        if (PPart^.FontStyles and afsFontItalic)<>0  then S+= '</i>';
        if (PPart^.FontStyles and afsFontBold)<>0  then S+= '</b>';
      end;
      ListLines.Add(S);
    end;

    _AddPreToStrings(ListLines);

    AOutput.Add('<html>');
    AOutput.Add('<head>');
    AOutput.Add('  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />');
    AOutput.Add('  <title>'+APageTitle+'</title>');
    AOutput.Add('</head>');

    if AFontName<>'' then
      AFontName+=',Consolas,Monaco,Lucida Console,monospace'
    else
      AFontName:= 'Consolas,Monaco,Lucida Console,Liberation Mono,DejaVu Sans Mono,Bitstream Vera Sans Mono,Courier New,monospace';
    AOutput.Add(Format('<body style="color: %s; background: %s; font-family: %s; font-size: %dpx;">', [
      TATHtmlColorParserA.ColorToHtmlString(NColorFont),
      TATHtmlColorParserA.ColorToHtmlString(AColorBg),
      AFontName,
      AFontSize
      ]));

    if AWithNumbers then
    begin
      AOutput.Add('<table style="border-style: hidden;">');
      AOutput.Add('<tr>');
      AOutput.Add('<td style="border-style: hidden; vertical-align: top; text-align: right; color: '+TATHtmlColorParserA.ColorToHtmlString(AColorNumbers)+';">');
      AOutput.AddStrings(ListNums);
      AOutput.Add('</td>');
      AOutput.Add('<td>');
    end;

    AOutput.AddStrings(ListLines);

    if AWithNumbers then
      AOutput.Add('</td></tr></table>');

    AOutput.Add('</body>');
    AOutput.Add('</html>');

  finally
    if Assigned(ListNums) then
      FreeAndNil(ListNums);
    FreeAndNil(ListLines);
  end;
end;

end.

