; Casper Training Studio — Windows kurulum dosyası (Inno Setup 6)
; Masaüstü sürümü yalnızca yönetici içindir (bkz. lib/features/home/desktop_admin_only.dart).
;
; GitHub Actions (.github/workflows/windows-desktop.yml) derler:
;   iscc /DAppVersion=1.0.0 /DBuildNumber=12 windows\installer\casper.iss
; Çıktı: build\installer\Casper-Kurulum-<sürüm>.exe
;
; Yönetici izni (UAC) istemez: kullanıcının kendi klasörüne (%LOCALAPPDATA%\Programs) kurulur.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif

[Setup]
AppId={{6F3C2E1A-8B4D-4C7E-9A21-5D0B7E3F1C42}
AppName=Casper Training Studio
AppVersion={#AppVersion} ({#BuildNumber})
AppVerName=Casper Training Studio {#AppVersion}
AppPublisher=Casper Training Studio
AppPublisherURL=https://www.instagram.com/caspertrainingstudio/
AppSupportURL=mailto:caspertrainingstudio@gmail.com
VersionInfoVersion={#AppVersion}.{#BuildNumber}
DefaultDirName={localappdata}\Programs\Casper Training Studio
DefaultGroupName=Casper Training Studio
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=Casper-Kurulum-{#AppVersion}-{#BuildNumber}
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\caspertrainingstudio.exe
UninstallDisplayName=Casper Training Studio (Yönetici)
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=yes

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstüne kısayol oluştur"; GroupDescription: "Kısayollar:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Casper Training Studio"; Filename: "{app}\caspertrainingstudio.exe"
Name: "{group}\Kaldır"; Filename: "{uninstallexe}"
Name: "{userdesktop}\Casper Training Studio"; Filename: "{app}\caspertrainingstudio.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\caspertrainingstudio.exe"; Description: "Casper Training Studio'yu başlat"; Flags: nowait postinstall skipifsilent
