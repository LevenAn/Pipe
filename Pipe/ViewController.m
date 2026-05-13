//
//  ViewController.m
//  Pipe
//

#import "ViewController.h"
#import "PipeDashboardViewController.h"
#import "PipePacketsViewController.h"
#import "PipeSettingsViewController.h"
#import "LocalizationManagerService.h"

@interface ViewController ()
@property (nonatomic, strong) UITabBarController *tabs;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];

    NSInteger savedLang = [[NSUserDefaults standardUserDefaults] integerForKey:@"PipeAppLanguage"];
    if (savedLang >= AppLanguageEnglish && savedLang <= AppLanguageFrench) {
        [LocalizationManagerService sharedService].preferredLanguage = (AppLanguage)savedLang;
    }

    UITabBarController *tabs = [[UITabBarController alloc] init];
    self.tabs = tabs;
    tabs.tabBar.tintColor = [UIColor colorWithRed:0.0 green:0.55 blue:1.0 alpha:1.0];
    if (@available(iOS 15.0, *)) {
        UITabBarAppearance *a = [[UITabBarAppearance alloc] init];
        [a configureWithDefaultBackground];
        a.backgroundColor = [UIColor colorWithRed:0.11 green:0.12 blue:0.14 alpha:1.0];
        tabs.tabBar.standardAppearance = a;
        tabs.tabBar.scrollEdgeAppearance = a;
    }

    LocalizationManagerService *L = [LocalizationManagerService sharedService];

    PipeDashboardViewController *dash = [[PipeDashboardViewController alloc] init];
    UINavigationController *n0 = [[UINavigationController alloc] initWithRootViewController:dash];
    n0.navigationBar.prefersLargeTitles = YES;
    dash.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    n0.tabBarItem = [[UITabBarItem alloc] initWithTitle:[L stringForKey:@"tab.dashboard"]
                                                 image:[UIImage systemImageNamed:@"gauge.with.dots.needle.67percent"]
                                                   tag:0];

    PipePacketsViewController *packets = [[PipePacketsViewController alloc] init];
    UINavigationController *n1 = [[UINavigationController alloc] initWithRootViewController:packets];
    n1.navigationBar.prefersLargeTitles = YES;
    packets.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    n1.tabBarItem = [[UITabBarItem alloc] initWithTitle:[L stringForKey:@"tab.packets"]
                                                 image:[UIImage systemImageNamed:@"list.bullet.rectangle"]
                                                   tag:1];

    PipeSettingsViewController *settings = [[PipeSettingsViewController alloc] init];
    UINavigationController *n2 = [[UINavigationController alloc] initWithRootViewController:settings];
    n2.navigationBar.prefersLargeTitles = YES;
    settings.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    n2.tabBarItem = [[UITabBarItem alloc] initWithTitle:[L stringForKey:@"tab.settings"]
                                                image:[UIImage systemImageNamed:@"gearshape"]
                                                  tag:2];

    tabs.viewControllers = @[n0, n1, n2];

    [self addChildViewController:tabs];
    tabs.view.frame = self.view.bounds;
    tabs.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tabs.view];
    [tabs didMoveToParentViewController:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onLanguageChange:)
                                                 name:@"PipeLanguageDidChange"
                                               object:nil];
}

- (void)onLanguageChange:(NSNotification *)note {
    LocalizationManagerService *L = [LocalizationManagerService sharedService];
    self.tabs.viewControllers[0].tabBarItem.title = [L stringForKey:@"tab.dashboard"];
    self.tabs.viewControllers[1].tabBarItem.title = [L stringForKey:@"tab.packets"];
    self.tabs.viewControllers[2].tabBarItem.title = [L stringForKey:@"tab.settings"];
    for (UINavigationController *nav in self.tabs.viewControllers) {
        UIViewController *root = nav.viewControllers.firstObject;
        if ([root isKindOfClass:[PipeDashboardViewController class]]) {
            root.title = [L stringForKey:@"tab.dashboard"];
        } else if ([root isKindOfClass:[PipePacketsViewController class]]) {
            root.title = [L stringForKey:@"tab.packets"];
        } else if ([root isKindOfClass:[PipeSettingsViewController class]]) {
            root.title = [L stringForKey:@"tab.settings"];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
