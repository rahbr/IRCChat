unit Unit1;

{$DEFINE DEBUG}

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls,inifiles, Buttons, ComCtrls, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdCmdTCPClient, IdIRC,
  IdContext, ExtCtrls, IdAntiFreezeBase, IdAntiFreeze;

type

  TForm1 = class(TForm)
    ButtonConfigurar: TBitBtn;
    StatusBar1: TStatusBar;
    ButtonConectar: TButton;
    IdIRC1: TIdIRC;
    Timer1: TTimer;
    Panel1: TPanel;
    Splitter1: TSplitter;
    Panel2: TPanel;
    ComboBoxNames: TComboBox;
    ButtonSend: TButton;
    EditSend: TMemo;
    Panel3: TPanel;
    LogRecebidas: TRichEdit;
    Label1: TLabel;
    IdAntiFreeze1: TIdAntiFreeze;
    Button1: TButton;
    procedure ButtonSendClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure EditSendKeyPress(Sender: TObject; var Key: Char);
    procedure ButtonConfigurarClick(Sender: TObject);
    procedure IdIRC1ServerError(ASender: TIdContext; AErrorCode: Integer;
      const AErrorMessage: String);
    procedure IdIRC1IsOnIRC(ASender: TIdContext; const ANickname,
      AHost: String);
    procedure IdIRC1UserInfoReceived(ASender: TIdContext;
      AUserInfo: TStrings);
    procedure IdIRC1NicknameChange(ASender: TIdContext; const AOldNickname,
      AHost, ANewNickname: String);
    procedure IdIRC1Notice(ASender: TIdContext; const ANicknameFrom, AHost,
      ANicknameTo, ANotice: String);
    procedure IdIRC1Connected(Sender: TObject);
    procedure IdIRC1Join(ASender: TIdContext; const ANickname, AHost,
      AChannel: String);
    procedure IdIRC1Status(ASender: TObject; const AStatus: TIdStatus;
      const AStatusText: String);
    procedure IdIRC1Raw(ASender: TIdContext; AIn: Boolean;
      const AMessage: String);
    procedure IdIRC1PrivateMessage(ASender: TIdContext;
      const ANicknameFrom, AHost, ANicknameTo, AMessage: String);
    procedure IdIRC1Part(ASender: TIdContext; const ANickname, AHost,
      AChannel: String);
    procedure TimerDisconect(Sender: TObject);
    procedure IdIRC1Disconnected(Sender: TObject);
    procedure LogRecebidasChange(Sender: TObject);
    procedure EditSendKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ButtonConnect(Sender: TObject);
    procedure ButtonDisconnect(Sender: TObject);
    procedure IdIRC1ServerUsersListReceived(ASender: TIdContext;
      AUsers: TStrings);
    procedure Button1Click(Sender: TObject);
  private
    IRCChannel: String;
    Users: TStrings;
    NickIdx: Integer;
    FInChannel: Boolean;

    procedure ConfiguraIRC();
    function Configura(): boolean;
    procedure Connect();
    procedure Disconnect();
    procedure Identify(Password: string);
    procedure Join(AChannel: string);
    procedure Part();
    procedure Nick(NickName: string);
    procedure ExibeConversa(ANickFrom, AMessage:string);
    procedure WaitFor(var BoolVar: Boolean; Timeout: Cardinal = 5);

  public
    { Public declarations }
    canSay: Boolean;
    procedure Say(ATarget, Texto: string);
  end;
const
  Version='04.10.2010 11:01';
var
  Form1: TForm1;

implementation

uses UnitConfig, ProcessUtil, SHELLAPI;

{$R *.dfm}

procedure Log(s: string);
var
  APath, ALogFile: String;
  TLogFile: TextFile;
begin
  ALogFile := 'log.txt';
  APath := ExtractFilePath(ALogFile);

  if (APath <> '') then
    ForceDirectories(APath);

  AssignFile(TLogFile, ALogFile);
  try
    if FileExists(ALogFile) then
      Append(TLogFile)
    else
      Rewrite(TLogFile);

    Writeln(TLogFile, s);
  finally
    {$I-}CloseFile(TLogFile);{$I+}
  end;
end;

procedure TForm1.Disconnect();
begin
  Part();
  IdIRC1.Disconnect();
end;

procedure TForm1.Connect();
begin
  FInChannel := False;
  NickIdx := Users.Count-1;
  IdIrc1.Nickname := Users[NickIdx];
  IdIRC1.AltNickname := Users[NickIdx];

  try
    IdIRC1.Connect();
  except

    if not idIRC1.Connected then
    begin
      MessageDlg('Erro ao tentar conectar:' + idIRC1.Host, mtError, [mbOK], 0);
      Exit;
    end;
  end;
end;

procedure TForm1.Identify(Password: string);
begin
  IdIRC1.Say('NickServ', 'IDENTIFY ' + IdIRC1.Password);
end;

procedure TForm1.Join(AChannel: string);
begin
  if (AChannel = '') then
    AChannel := IRCChannel;

  if AChannel[1]<>'#' then
    AChannel := '#' + AChannel ;

  //  if not Identified then
  IdIRC1.Raw(Format('JOIN %s', [AChannel]));
end;

procedure TForm1.Say(ATarget, Texto: string);
var
  AMsg: string;
begin
  //Refresh timer
  Timer1.Enabled := False;
  Timer1.Enabled := True;

  //ops... algo aconteceu!
  if not canSay then
    Exit;

  if ATarget='' then
    ATarget := '#'+IRCChannel;

  ATarget := StringReplace(ATarget,'@','',[rfReplaceAll]);
  ATarget := StringReplace(ATarget,'+','',[rfReplaceAll]);
  AMsg := StringReplace(AMsg, #13, '',[rfReplaceAll]);
  AMsg := StringReplace(AMsg, #10, ' ',[rfReplaceAll]);
  AMsg := Format('[%s] %s',[IdIRC1.RealName, Texto]);

  IdIRC1.Raw(Format('PRIVMSG %s :%s', [ATarget, AMsg]));

  if ATarget = '#'+IRCChannel then
    LogRecebidas.Lines.Add(AMsg)
  else
  begin
    LogRecebidas.Lines.Add(Format('[%s] <%s>: %s',[IdIRC1.RealName, ATarget, Texto]));
  end;
end;

procedure TForm1.WaitFor(var BoolVar: Boolean; Timeout: Cardinal = 5);
var
  start: Cardinal;
begin
  start := GetTickCount();
  while (not BoolVar) and (GetTickCount() - start < (Timeout*1000)) do
    Application.ProcessMessages;
end;

procedure TForm1.ButtonSendClick(Sender: TObject);
begin
  EditSend.SetFocus();
  if not IdIRC1.Connected then
  begin
    ConfiguraIRC();
    Connect();
    Join(IRCChannel);
   end;

  WaitFor(FInChannel);
  try
    Say(ComboBoxNames.Text, EditSend.Text);
    EditSend.Lines.Clear();
  except
    MessageDlg('Erro ao tentar entrar no canal: ' + idIRC1.Host, mtError, [mbOK], 0);
    Disconnect();
    Exit;
  end;
end;

procedure TForm1.ConfiguraIRC();
var
  Ini: TCustomIniFile;
  //old: boolean;
begin
  //old := Timer1.Enabled;
  //Timer1.Enabled := False;
  Ini := TMemIniFile.Create(ExtractFilePath(ParamStr(0)) + '\config.ini');
  try
    IdIRC1.Host := ini.readstring('irc', 'host', '200.142.160.127');
    IdIRC1.Port := ini.ReadInteger('irc', 'port', 8000);
    IdIRC1.Username := ini.readstring('irc', 'username', '');
    IdIRC1.Password := ini.readstring('irc', 'password', '');
    IdIRC1.AltNickname := ini.readstring('irc', 'altnick', '');
    IdIRC1.RealName := ini.readstring('irc', 'realname', '');
    IRCChannel := ini.readstring('irc', 'channel', '');
    //Timer1.Interval := ini.ReadInteger('irc', 'timetodisconnect', 3000);
    Ini.ReadSection('Usuarios', Users);
  finally
    Ini.Free();
  end;
  //Timer1.Enabled := old;
  StatusBar1.Panels[1].Text := format('%s : %d - [%s]', [IdIRC1.Host, IdIRC1.Port, IdIRC1.RealName]);
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Users := TStringList.Create();
  LogRecebidas.lines.clear();
  FInChannel := False;
  ComboBoxNames.Items.Text := '#'+IRCChannel;
  ComboBoxNames.ItemIndex := 0;

  if not Configura() then
    Halt;
    
  ConfiguraIRC();
  Connect();
  Timer1.interval := 2*60*1000;
  Label1.Caption := Version;
end;

procedure TForm1.EditSendKeyPress(Sender: TObject; var Key: Char);
begin
  if key = #27 then
    EditSend.Lines.clear();

  if key = #13 then
  begin
    ButtonSendClick(nil);
    EditSend.Lines.clear();
    Key := #0;
  end;
 
end;

function TForm1.Configura(): boolean;
begin
  with TFormConfig.Create(self) do
  try
    result := ShowModal()= mrOK;
  finally
    Free();
  end;
end;

procedure TForm1.ButtonConfigurarClick(Sender: TObject);
begin
  if Configura() then
  begin
    Disconnect();
    ConfiguraIRC();
    Connect();
end;
end;

procedure TForm1.Part;
begin
  Timer1.Enabled := False;
  IdIRC1.Part('#'+IRCChannel);
end;

procedure TForm1.Nick(NickName: string);
begin
  IdIRC1.Raw(format('NICK %s',[NickName]));
end;

procedure TForm1.IdIRC1ServerError(ASender: TIdContext;
  AErrorCode: Integer; const AErrorMessage: String);
begin
  Log('ServerError:'+AErrorMessage);
  ShowMessage('ServerError:'+AErrorMessage);
end;

procedure TForm1.IdIRC1IsOnIRC(ASender: TIdContext; const ANickname,
  AHost: String);
begin
  Log('isonIRC');
end;

procedure TForm1.IdIRC1UserInfoReceived(ASender: TIdContext;
  AUserInfo: TStrings);
begin
{$IFDEF DEBUG}
  Log('inforeceived'+AUserInfo.Text);
  LogRecebidas.Lines.Add('inforeceived:'+#13+AUserInfo.Text);
{$ENDIF}
end;

procedure TForm1.IdIRC1NicknameChange(ASender: TIdContext;
  const AOldNickname, AHost, ANewNickname: String);
begin
  {$IFDEF DEBUG}
  Log(Format('NickNameChange'+#10+'OLD=%s NEW=%s Host=%s',
    [AOldNickname+#10, ANewNickname+#10, AHost+#10]));
  {$ENDIF}
end;

procedure TForm1.IdIRC1Notice(ASender: TIdContext; const ANicknameFrom,
  AHost, ANicknameTo, ANotice: String);
begin
  //need Identify
  if Pos('IDENTIFY_REQUEST', ANotice)>0 then
    Identify(IdIRC1.Password);

  //Do Join
  if Pos('IDENTIFY Password accepted', ANotice)>0 then
    Join(IRCChannel);

{$IFDEF DEBUG}
  Log('OnNotice'+#13+'nick:' + ANicknameFrom +' host:'+ AHost +
  ' to:'+ ANicknameTo + ' notice:' + ANotice);
{$ENDIF}

end;

procedure TForm1.IdIRC1Connected(Sender: TObject);
begin
{$IFDEF DEBUG}
  Log('Conectado.');
{$ENDIF}

  ButtonConectar.Caption := 'Desconectar';
  ButtonConectar.OnClick := ButtonDisconnect;
  Timer1.Enabled := True;
end;

procedure TForm1.IdIRC1Status(ASender: TObject; const AStatus: TIdStatus;
  const AStatusText: String);
begin
  {$IFDEF DEBUG}
  Log('Status:'+AStatusText);
  {$ENDIF}
  StatusBar1.Panels[0].Text := AStatusText;
end;

function ParseNames(s:string):string;
var
  Lista:TStrings;
begin
  Lista := TStringList.Create();
  Lista.Delimiter := ' ';
  Lista.CommaText := Copy(s, pos(':', s) + 1, Length(s));
  Result := Lista.Text;
end;

procedure TForm1.IdIRC1Raw(ASender: TIdContext; AIn: Boolean;
  const AMessage: String);
var
  oldDest: string;
begin
  {$IFDEF DEBUG}
  Log('OnRaw: ' + AMessage);
  {$ENDIF}

  //User in uso, tenta alterar nick
  if Copy(AMessage, 1, 3) ='433' then
  begin
    Dec(NickIdx);
    if NickIdx<0 then
      IdIRC1.Disconnect();
    Nick(Users[NickIdx]);
  end;

  //lista de usuarios
  if Copy(AMessage, 1, 3) ='353' then
  begin
    oldDest := ComboBoxNames.Text;
  //353 Antena04 = #ip-sesc :@SescApoio SescADM @SescDN Antena05 @carlos DNAndre Antena04
    ComboBoxNames.Enabled := True;
    ComboBoxNames.Items.Text := ParseNames(AMessage);
    ComboBoxNames.Items.Insert(0, '#'+IRCChannel);
    ComboBoxNames.ItemIndex := ComboBoxNames.Items.IndexOf(oldDest);

    canSay := True;
    if ComboBoxNames.Items.IndexOf(oldDest) < -1 then
    begin
      ShowMessage('Usuário "'+oldDest+'" desconectou-se, a mensagem não será enviada!');
      canSay := False;
    end;

    if ComboBoxNames.ItemIndex < 0 then
      ComboBoxNames.ItemIndex := 0;
  end;

  if Copy(AMessage, 1,3) = '401' then
  begin
    oldDest := 'O usuario não está mais conectado'+#10+
      'Tente enviar a mensagem para o chat público: #' + IRCChannel;
    LogRecebidas.SelAttributes.Style := [fsBold];
    LogRecebidas.SelAttributes.Color := clTeal;    
    LogRecebidas.Lines.Add(oldDest);
    LogRecebidas.SelAttributes.Color := clBtnText;
  end;
end;

procedure TForm1.IdIRC1PrivateMessage(ASender: TIdContext;
  const ANicknameFrom, AHost, ANicknameTo, AMessage: String);
begin
  if SameText(ANicknameTo, '#ip-sesc') then
  begin
    LogRecebidas.Lines.Add(Format('<%s> %s',[ANicknameFrom, AMessage]));
  end
  else
    ExibeConversa(ANicknameFrom, AMessage);
end;


procedure TForm1.ExibeConversa(ANickFrom, AMessage: string);
begin
  LogRecebidas.SelAttributes.Style := [fsBold];
  LogRecebidas.Lines.Add(Format('<%s> [%s]: %s',[IdIRC1.RealName,ANickFrom, AMessage]));
  LogRecebidas.SelAttributes.Color := clBtnText;
end;

procedure TForm1.TimerDisconect(Sender: TObject);
var
  T: boolean;
begin
  FInChannel := False;
  IdIRC1.ListChannelNicknames('#'+IRCChannel);
  WaitFor(T, 5);
  Disconnect();
end;

procedure TForm1.IdIRC1Disconnected(Sender: TObject);
begin
  Timer1.Enabled := False;
  LogRecebidas.SelAttributes.Color := clRed;
  LogRecebidas.SelAttributes.Style := [fsBold];
  LogRecebidas.Lines.Add('<< Desconectado automaticamente.');
  LogRecebidas.SelAttributes.Color := clBtnText;

  ButtonConectar.Caption := 'Conectar';
  ButtonConectar.OnClick := ButtonConnect;
end;

procedure TForm1.LogRecebidasChange(Sender: TObject);
begin
  //Rola a tela para a última linha adicionada
  SendMessage(LogRecebidas.Handle, WM_VSCROLL, SB_PAGEDOWN, 0);
end;

procedure TForm1.EditSendKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  StatusBar1.Panels[0].Text :=
    Format('Resta: %d', [(length(EditSend.Lines.Text) - 255)*-1]);

  ButtonSend.Enabled := (Length(EditSend.Lines.Text) >0);// and IdIRC1.Connected;
end;

procedure TForm1.ButtonConnect(Sender: TObject);
begin
  Connect();
end;

procedure TForm1.ButtonDisconnect(Sender: TObject);
begin
  Disconnect();
end;

procedure TForm1.IdIRC1ServerUsersListReceived(ASender: TIdContext;
  AUsers: TStrings);
begin
{$IFDEF DEBUG}
//exibe a lista  de pessoas online
  LogRecebidas.Lines.AddStrings(AUsers);
{$ENDIF}
end;

procedure TForm1.IdIRC1Join(ASender: TIdContext; const ANickname, AHost,
  AChannel: String);
begin
{$IFDEF DEBUG}
  LogRecebidas.Lines.Add('>>Usuário ' + ANickname + ' conectou-se');
{$ENDIF}
  //adiciona na lista caso não exista
  if not (ComboBoxNames.Items.IndexOf(ANickname)>-1) then
    ComboBoxNames.Items.Add(ANickname);

  //se for meu nome, avisa que estou no canal.
  if Pos(ANickname, IdIRC1.Nickname)>0 then
    FInChannel := True;
end;

procedure TForm1.IdIRC1Part(ASender: TIdContext; const ANickname, AHost,
  AChannel: String);
var
  i: Integer;
begin
  //retira da lista caso exista.
  i := ComboBoxNames.Items.IndexOf(ANickname);
  if i >-1 then
  begin
    ComboBoxNames.Items.Delete(i);

    if (ComboBoxNames.ItemIndex=i) then
      ComboBoxNames.ItemIndex := 0;
  end;

  //se for meu nome, avisa que estou no canal.
  if Pos(LowerCase(ANickname), LowerCase(IdIRC1.Nickname))>0 then
    FInChannel := False
{$IFDEF DEBUG}
  else
    LogRecebidas.Lines.Add('<<Usuário ' + ANickname + ' desconectou-se')
{$ENDIF}
  ;

end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if FileExists('manual.mht') then
    ShellExecute(Application.Handle, nil,'manual.mht', nil, nil, SW_SHOWNORMAL)
  else
    ShowMessage('Arquivo "manual.mht" não encontrado!');
end;

end.

{procedure TForm1.Flashing(bValue: boolean);
begin
  FlashWindow(Handle, bValue); // The current form
  FlashWindow(Application.Handle, bValue); // The app button on the taskbar
end;}

