# Minimo ayarları

Minimo OS'un bu bilgisayardaki kendi oturumu için ayarları: serpantinum'un
(Hyprland) ve Plasma'nın ayarlarına dokunmadan, SDDM'de ayrı bir "Minimo OS"
oturumu. Minimo'nun kendisi `~/Proyectos/minimo-os` deposundadır (`yerel` dalı:
Türkçe, kitty, ada düzeltmeleri); bu depo onun çevresindeki ayarları tutar.

Dosyalar `ev/` altında, `$HOME`'daki yerleriyle aynı yollarda durur; `$HOME`'daki
asılları bunlara giden bağlantılardır. Burada değiştirilen, Minimo'da geçerlidir.

## İçerik

| Dosya | Ne yapar |
|---|---|
| `.config/hypr/minimo-oturum.lua` | Minimo oturumunun Hyprland ayarı (`--config` ile; `hyprland.lua` okunmaz) |
| `.config/hypr/minimo/serbest.lua` | Serbest (yüzen) pencereler, Super+W/G/M, docka gizleme, pencereyi ekrana sığdırma |
| `.config/hypr/minimo/cubuk.lua` | Yüzen pencerelere başlık çubuğu ve – □ ✕ düğmeleri (hyprbars), temaya uyan renkler |
| `.config/hypr/minimo/terminal.lua` | Super+T → kitty |
| `.config/hypr/minimo/entrada.lua` | Türkçe Q klavye, Alt+Shift ile İngilizce |
| `.config/hypr/minimo/monitores.lua` | Ekran |
| `.config/pleamar/shells/minimo-dock/` | Dock (pleamar-wm'in "kıyı"sı gibi), akıllı gizlenme |
| `.config/pleamar/shells/minimo-keys/keys.plm` | Duvar kâğıdında Türkçe kısayol ve hareket kartı |
| `.config/systemd/user/minimo-*` | Yalnızca Minimo oturumunda çalışan servisler (`minimo-session.target`) |
| `.config/minimo-mimeapps.list` | Minimo'ya özel varsayılan uygulamalar (klasörler → Nautilus) |
| `.config/minimo-os/dock.json` | Dock'ta sabitlenen uygulamalar |
| `.local/share/applications/com.mitchellh.ghostty.desktop` | Ghostty menüde yalnızca Minimo'da |
| `.local/bin/minimo-guncelle` | Minimo'yu `install.sh` olmadan güncelleme |
| `.local/bin/xdg-terminal-exec` | Terminal isteyen programlara Minimo'da kitty, başka oturumlarda Konsole |
| `sistem/` | Root dosyaları: oturum başlatıcısı ve SDDM kaydı |

## Kurulum (yeniden)

    ~/Proyectos/minimo-ayarlar/kur.sh

Betik bağlantıları kurar, servisleri etkinleştirir ve root dosyaları için
gereken iki `sudo` komutunu yazar.

## Güncelleme

    minimo-guncelle

Minimo'nun `install.sh` betiğini çalıştırmayın: Minimo'yu serpantinum'un ve
SDDM'in yerine kurar.
