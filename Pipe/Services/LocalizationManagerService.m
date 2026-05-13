//
//  LocalizationManagerService.m
//  Pipe
//

#import "LocalizationManagerService.h"

static NSString *LanguageCode(AppLanguage lang) {
    switch (lang) {
        case AppLanguageChinese: return @"zh-Hans";
        case AppLanguageJapanese: return @"ja";
        case AppLanguageSpanish: return @"es";
        case AppLanguageFrench: return @"fr";
        default: return @"en";
    }
}

static NSDictionary *TableForCode(NSString *code, NSDictionary *bundles) {
    NSDictionary *t = bundles[code];
    if (t) {
        return t;
    }
    return bundles[@"en"] ?: @{};
}

@implementation LocalizationManagerService {
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *_bundles;
}

+ (instancetype)sharedService {
    static LocalizationManagerService *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[self alloc] init]; });
    return s;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bundles = [self buildStringTables];
        _preferredLanguage = AppLanguageEnglish;
    }
    return self;
}

- (NSDictionary *)buildStringTables {
    NSDictionary *en = @{
        @"app.name": @"Pipe",
        @"tab.dashboard": @"Dashboard",
        @"tab.packets": @"Packets",
        @"tab.settings": @"Settings",
        @"vpn.status": @"VPN: %@",
        @"vpn.connect": @"Connect VPN",
        @"vpn.disconnect": @"Disconnect",
        @"vpn.configure": @"Use IKEv2 in settings. WireGuard/OpenVPN need a tunnel extension.",
        @"capture.status": @"Capture: %@",
        @"capture.running": @"Running",
        @"capture.stopped": @"Stopped",
        @"capture.start": @"Start capture",
        @"capture.stop": @"Stop capture",
        @"capture.simulate": @"Simulate sample traffic",
        @"metrics.packets": @"Packets: %@",
        @"metrics.filtered": @"Filtered: %@",
        @"packets.search": @"Search host, IP or payload",
        @"packets.empty": @"No packets yet. Start capture or tap Simulate.",
        @"packets.detail": @"Details",
        @"settings.title": @"Settings",
        @"settings.language": @"Language",
        @"settings.vpn_exclusion": @"Exclude VPN tunnel traffic",
        @"settings.private_mode": @"Private capture (no disk)",
        @"settings.export_pcap": @"Export PCAP…",
        @"settings.clear": @"Clear packets",
        @"export.done": @"Export finished",
        @"export.fail": @"Export failed",
        @"language.english": @"English",
        @"language.chinese": @"简体中文",
        @"language.japanese": @"日本語",
        @"language.spanish": @"Español",
        @"language.french": @"Français"
    };
    NSDictionary *zh = @{
        @"app.name": @"Pipe",
        @"tab.dashboard": @"总览",
        @"tab.packets": @"抓包",
        @"tab.settings": @"设置",
        @"vpn.status": @"VPN: %@",
        @"vpn.connect": @"连接 VPN",
        @"vpn.disconnect": @"断开",
        @"vpn.configure": @"IKEv2 可在设置中配置。WireGuard/OpenVPN 需 Packet Tunnel 扩展。",
        @"capture.status": @"抓包: %@",
        @"capture.running": @"进行中",
        @"capture.stopped": @"已停止",
        @"capture.start": @"开始抓包",
        @"capture.stop": @"停止抓包",
        @"capture.simulate": @"模拟示例流量",
        @"metrics.packets": @"数据包: %@",
        @"metrics.filtered": @"已过滤: %@",
        @"packets.search": @"搜索 IP / 主机 / 内容",
        @"packets.empty": @"暂无数据。开始抓包或点「模拟」",
        @"packets.detail": @"详情",
        @"settings.title": @"设置",
        @"settings.language": @"界面语言",
        @"settings.vpn_exclusion": @"排除 VPN 隧道流量",
        @"settings.private_mode": @"隐私模式（不落盘）",
        @"settings.export_pcap": @"导出 PCAP…",
        @"settings.clear": @"清空列表",
        @"export.done": @"导出完成",
        @"export.fail": @"导出失败",
        @"language.english": @"English",
        @"language.chinese": @"简体中文",
        @"language.japanese": @"日本語",
        @"language.spanish": @"Español",
        @"language.french": @"Français"
    };
    NSDictionary *ja = @{
        @"tab.dashboard": @"ダッシュボード",
        @"tab.packets": @"パケット",
        @"tab.settings": @"設定",
        @"vpn.connect": @"VPN接続",
        @"vpn.disconnect": @"切断",
        @"capture.start": @"キャプチャ開始",
        @"capture.stop": @"キャプチャ停止",
        @"capture.simulate": @"サンプル生成",
        @"settings.title": @"設定",
        @"settings.export_pcap": @"PCAP書き出し…",
        @"settings.clear": @"クリア"
    };
    NSDictionary *es = @{
        @"tab.dashboard": @"Panel",
        @"tab.packets": @"Paquetes",
        @"tab.settings": @"Ajustes",
        @"vpn.connect": @"Conectar VPN",
        @"vpn.disconnect": @"Desconectar",
        @"capture.start": @"Iniciar captura",
        @"capture.stop": @"Detener captura",
        @"settings.title": @"Ajustes",
        @"settings.export_pcap": @"Exportar PCAP…"
    };
    NSDictionary *fr = @{
        @"tab.dashboard": @"Tableau de bord",
        @"tab.packets": @"Paquets",
        @"tab.settings": @"Réglages",
        @"vpn.connect": @"Connecter VPN",
        @"vpn.disconnect": @"Déconnecter",
        @"capture.start": @"Démarrer capture",
        @"capture.stop": @"Arrêter capture",
        @"settings.title": @"Réglages",
        @"settings.export_pcap": @"Exporter PCAP…"
    };
    return @{ @"en": en, @"zh-Hans": zh, @"ja": ja, @"es": es, @"fr": fr };
}

- (void)applyPreferredLanguageFromUISettings:(UISettings *)uiSettings {
    if (!uiSettings) {
        return;
    }
    self.preferredLanguage = uiSettings.language;
}

- (NSString *)activeLanguageCode {
    return LanguageCode(self.preferredLanguage);
}

- (NSString *)stringForKey:(NSString *)key {
    return [self stringForKey:key arguments:nil];
}

- (NSString *)stringForKey:(NSString *)key arguments:(NSArray<id> *)arguments {
    NSString *code = [self activeLanguageCode];
    NSDictionary *primary = TableForCode(code, _bundles);
    NSString *value = primary[key];
    if (!value.length) {
        value = TableForCode(@"en", _bundles)[key] ?: key;
    }
    if (arguments.count == 0) {
        return value;
    }
    return [NSString stringWithFormat:value, arguments[0], arguments.count > 1 ? arguments[1] : @""];
}

@end
