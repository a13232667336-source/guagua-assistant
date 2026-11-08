//
//  ModernSettingsViewController.m
//  呱呱助手
//
//  Created by BandarHelal on 25/11/2021.
//

#import "Settings/ModernSettingsViewController.h"
#import "Core/BHTBundle.h"
#import "Core/NFBEmbedded.h"
#import "Core/BHTManager.h"
#import "Settings/ModernSettingsCells.h"
#import "Settings/ModernSettingsPageViewController.h"
#import "ThemeColor/Palette.h"

@interface ModernSettingsViewController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) TFNTwitterAccount* account;
@property (nonatomic, strong) UITableView* tableView;
@property (nonatomic, strong) NSArray* sections;
@property (nonatomic, strong) NSArray* developerCells;
@property (nonatomic, strong) NSArray* coolKidsCells;
@property (nonatomic, strong) NSArray* specialThanksCells;
@property (nonatomic, strong) NSArray* officialPageCells;
@property (nonatomic, strong) NSArray* contributorCells;
@end

@implementation ModernSettingsViewController

#pragma mark - Section Headers

- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return [self headerViewWithTitle:[[BHTBundle sharedBundle]
                                             localizedStringForKey:@"DEVELOPER_SECTION_HEADER_TITLE"]];
    }
    UIView* spacer = [[UIView alloc] init];
    spacer.backgroundColor = [Palette currentBackgroundColor];
    return spacer;
}

- (UIView*)headerViewWithTitle:(NSString*)title {
    UIView* headerView = [[UIView alloc] init];
    headerView.backgroundColor = [Palette currentBackgroundColor];

    UILabel* titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;

    id fontGroup = [BHTManager sharedFontGroup];
    titleLabel.font = [fontGroup performSelector:@selector(headline1BoldFont)];

    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    UIColor* titleColor = [colorPalette performSelector:@selector(textColor)];
    titleLabel.textColor = titleColor;

    [headerView addSubview:titleLabel];

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.leadingAnchor constraintEqualToAnchor:headerView.leadingAnchor
                                                 constant:20],
        [titleLabel.trailingAnchor constraintEqualToAnchor:headerView.trailingAnchor
                                                  constant:-20],
        [titleLabel.topAnchor constraintEqualToAnchor:headerView.topAnchor
                                             constant:32],
        [titleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor
                                                constant:-16]
    ]];

    return headerView;
}

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return UITableViewAutomaticDimension;
    }
    return 8.0;
}

#pragma mark - Section Footers

- (UIView*)tableView:(UITableView*)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 0) {
        UIView* separator = [[UIView alloc] initWithFrame:CGRectZero];
        separator.backgroundColor = [UIColor separatorColor];
        return separator;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView*)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) {
        return 1.0 / UIScreen.mainScreen.scale;
    }
    return CGFLOAT_MIN;
}

#pragma mark - Lifecycle & Setup

- (instancetype)initWithAccount:(TFNTwitterAccount*)account {
    self = [super init];
    if (self) {
        _account = account;
        [self setupSections];
        [self setupDeveloperCells];
    }
    return self;
}

- (void)setupSections {
    self.sections = @[
        @{
            @"title" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_TITLE"],
            @"subtitle" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_LAYOUT_SUBTITLE"],
            @"icon" : @"settings_stroke",
            @"action" : @"showLayoutSettings"
        },
        @{
            @"title" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TIMELINES_TITLE"],
            @"subtitle" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_TIMELINES_SUBTITLE"],
            @"icon" : @"home_stroke",
            @"action" : @"showTimelinesSettings"
        },
        @{
            @"title" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_TITLE"],
            @"subtitle" : [[BHTBundle sharedBundle] localizedStringForKey:@"MODERN_SETTINGS_MEDIA_SUBTITLE"],
            @"icon" : @"media_tab_stroke",
            @"action" : @"showDownloadsSettings"
        }
    ];
}

- (void)setupDeveloperCells {
    self.developerCells = @[ @{
        @"title" : @"Samuel",
        @"role" : @"开发者",
        @"avatarEmbedded" : @YES
    } ];
    self.coolKidsCells = @[];
    self.specialThanksCells = @[];
    self.contributorCells = @[];
    self.officialPageCells = @[];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationBar];
    [self setupTableView];
    [self setupLayout];
    [self setupFooterLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contentSizeCategoryDidChange:)
                                                 name:UIContentSizeCategoryDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)contentSizeCategoryDidChange:(NSNotification*)notification {
    [self.tableView reloadData];
}

- (void)setupNavigationBar {
    self.view.backgroundColor = [Palette currentBackgroundColor];
    if (self.account) {
        self.navigationItem.titleView = [objc_getClass("TFNTitleView")
            titleViewWithTitle:[[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"]
                      subtitle:self.account.displayUsername];
    } else {
        self.title = [[BHTBundle sharedBundle] localizedStringForKey:@"NFB_SETTINGS_TITLE"];
    }
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [Palette currentBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.estimatedRowHeight = 80;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedSectionHeaderHeight = 50;
    self.tableView.sectionHeaderHeight = UITableViewAutomaticDimension;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    [self.tableView registerClass:[ModernSettingsTableViewCell class]
           forCellReuseIdentifier:@"SettingsCell"];
    [self.view addSubview:self.tableView];
}

- (void)setupLayout {
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)setupFooterLabel {
    UIView* footerView =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    footerView.backgroundColor = [Palette currentBackgroundColor];

    UILabel* footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.text = @NFB_VERSION_STRING " (" NFB_COMMIT_STRING ")";
    footerLabel.numberOfLines = 0;
    footerLabel.textAlignment = NSTextAlignmentLeft;
    footerLabel.userInteractionEnabled = YES;

    footerLabel.font = TwitterChirpFont(TwitterFontStyleRegular);

    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    UIColor* subtitleColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    footerLabel.textColor = subtitleColor;

    [footerView addSubview:footerLabel];

    [NSLayoutConstraint activateConstraints:@[
        [footerLabel.leadingAnchor constraintEqualToAnchor:footerView.leadingAnchor
                                                  constant:20], // match table cell padding
        [footerLabel.trailingAnchor constraintEqualToAnchor:footerView.trailingAnchor
                                                   constant:-20],
        [footerLabel.topAnchor constraintEqualToAnchor:footerView.topAnchor
                                              constant:8],
        [footerLabel.bottomAnchor constraintEqualToAnchor:footerView.bottomAnchor
                                                 constant:-8]
    ]];

    UITapGestureRecognizer* tapGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self
                                                action:@selector(footerLabelTapped:)];
    [footerLabel addGestureRecognizer:tapGesture];
    UILongPressGestureRecognizer* longPressGesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                      action:@selector(footerLabelLongPressed:)];
    [footerLabel addGestureRecognizer:longPressGesture];

    self.tableView.tableFooterView = footerView;
}

- (void)footerLabelTapped:(UIGestureRecognizer*)sender {
    NSURL* url = [NSURL URLWithString:@"https://github.com/orionblur/呱呱助手"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}
- (void)footerLabelLongPressed:(UILongPressGestureRecognizer*)sender {
    if (sender.state == UIGestureRecognizerStateBegan) {
        NSURL* url = [NSURL URLWithString:@"https://www.youtube.com/watch?v=UxbyOQgTsVc"];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.sections.count;
    } else if (section == 1) {
        return self.developerCells.count;
    }
    return 0;
}

- (UITableViewCell*)tableView:(UITableView*)tableView
        cellForRowAtIndexPath:(NSIndexPath*)indexPath {
    if (indexPath.section == 0) {
        ModernSettingsTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"SettingsCell"
                                                                            forIndexPath:indexPath];
        NSDictionary* sectionData = self.sections[indexPath.row];
        [cell configureWithTitle:sectionData[@"title"]
                        subtitle:sectionData[@"subtitle"]
                        iconName:sectionData[@"icon"]];
        return cell;
    } else if (indexPath.section == 1) {
        return [self developerCellForTableView:tableView
                                   atIndexPath:indexPath
                                     fromArray:self.developerCells];
    }

    return nil;
}

- (UITableViewCell*)developerCellForTableView:(UITableView*)tableView
                                  atIndexPath:(NSIndexPath*)indexPath
                                    fromArray:(NSArray*)array {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"DeveloperCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"DeveloperCell"];
        [self setupDeveloperCell:cell];
    }
    NSDictionary* developer = array[indexPath.row];
    [self configureDeveloperCell:cell withDeveloper:developer];
    return cell;
}

#pragma mark - Developer Cell Setup

- (void)setupDeveloperCell:(UITableViewCell*)cell {
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.imageView.image = nil;
    UIImageView* avatarImageView = [[UIImageView alloc] init];
    avatarImageView.translatesAutoresizingMaskIntoConstraints = NO;
    avatarImageView.layer.cornerRadius = 26;
    avatarImageView.clipsToBounds = YES;
    avatarImageView.contentMode = UIViewContentModeScaleAspectFill;
    avatarImageView.tag = 100;
    [cell.contentView addSubview:avatarImageView];
    UILabel* nameLabel = [[UILabel alloc] init];
    nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    nameLabel.tag = 101;
    nameLabel.adjustsFontForContentSizeCategory = YES;
    [cell.contentView addSubview:nameLabel];
    UILabel* usernameLabel = [[UILabel alloc] init];
    usernameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    usernameLabel.tag = 102;
    usernameLabel.adjustsFontForContentSizeCategory = YES;
    [cell.contentView addSubview:usernameLabel];
    UIImageView* devChevron = [[UIImageView alloc] init];
    devChevron.translatesAutoresizingMaskIntoConstraints = NO;
    devChevron.tag = 103;
    devChevron.contentMode = UIViewContentModeScaleAspectFit;
    [cell.contentView addSubview:devChevron];
    [NSLayoutConstraint activateConstraints:@[
        [avatarImageView.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor
                                                      constant:20],
        [avatarImageView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [avatarImageView.widthAnchor constraintEqualToConstant:52],
        [avatarImageView.heightAnchor constraintEqualToConstant:52],
        [nameLabel.leadingAnchor constraintEqualToAnchor:avatarImageView.trailingAnchor
                                                constant:12],
        [nameLabel.trailingAnchor constraintEqualToAnchor:devChevron.leadingAnchor
                                                 constant:-12],
        [nameLabel.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor
                                            constant:16],
        [usernameLabel.leadingAnchor constraintEqualToAnchor:nameLabel.leadingAnchor],
        [usernameLabel.trailingAnchor constraintEqualToAnchor:devChevron.leadingAnchor
                                                     constant:-12],
        [usernameLabel.topAnchor constraintEqualToAnchor:nameLabel.bottomAnchor
                                                constant:2],
        [usernameLabel.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor
                                                   constant:-16],
        [devChevron.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor
                                                  constant:-20],
        [devChevron.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
        [devChevron.widthAnchor constraintEqualToConstant:18],
        [devChevron.heightAnchor constraintEqualToConstant:18]
    ]];
    cell.backgroundColor = [Palette currentBackgroundColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
}

- (void)configureDeveloperCell:(UITableViewCell*)cell withDeveloper:(NSDictionary*)developer {
    UIImageView* avatarImageView = [cell.contentView viewWithTag:100];
    UILabel* nameLabel = [cell.contentView viewWithTag:101];
    UILabel* usernameLabel = [cell.contentView viewWithTag:102];
    id fontGroup = [BHTManager sharedFontGroup];
    Class TAEColorSettingsCls = objc_getClass("TAEColorSettings");
    id settings = [TAEColorSettingsCls sharedSettings];
    id currentPalette = [settings currentColorPalette];
    id colorPalette = [currentPalette colorPalette];
    UIColor* textColor = [colorPalette performSelector:@selector(textColor)];
    UIColor* subtitleColor = [colorPalette performSelector:@selector(tabBarItemColor)];
    nameLabel.text = developer[@"title"];
    nameLabel.font = [fontGroup performSelector:@selector(bodyBoldFont)];
    nameLabel.textColor = textColor;
    NSString* role = developer[@"role"];
    if (role.length == 0) {
        role = [NSString stringWithFormat:@"@%@", developer[@"username"] ?: @""];
    }
    usernameLabel.text = role;
    usernameLabel.font = [fontGroup performSelector:@selector(subtext2Font)];
    usernameLabel.textColor = subtitleColor;
    UIImageView* devChevron = [cell.contentView viewWithTag:103];
    devChevron.image = [UIImage tfn_vectorImageNamed:@"chevron_right"
                                            fitsSize:CGSizeMake(18, 18)
                                           fillColor:subtitleColor];
    if ([developer[@"avatarEmbedded"] boolValue]) {
        avatarImageView.image = NFBEmbeddedAvatar() ?: [UIImage systemImageNamed:@"person.circle.fill"];
        return;
    }
    NSString* avatarURL = developer[@"avatarURL"];
    if (avatarURL.length > 0) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:avatarURL]];
            UIImage* img = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                avatarImageView.image = img ?: [UIImage systemImageNamed:@"person.circle.fill"];
            });
        });
    } else {
        avatarImageView.image = [UIImage systemImageNamed:@"person.circle.fill"];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0) {
        NSDictionary* sectionData = self.sections[indexPath.row];
        NSString* action = sectionData[@"action"];
        SEL selector = NSSelectorFromString(action);
        if ([self respondsToSelector:selector]) {
            IMP imp = [self methodForSelector:selector];
            void (*func)(id, SEL) = (void*)imp;
            func(self, selector);
        }
    } else if (indexPath.section == 1) {
        NSDictionary* developer = self.developerCells[indexPath.row];
        [self openTwitterProfileWithUserID:developer[@"userID"]];
        }
}

- (void)openTwitterProfileWithUserID:(NSString*)userID {
    if (!userID.length) return;
    NSString* twitterURL = [NSString stringWithFormat:@"twitter://user?id=%@", userID];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:twitterURL]
                                       options:@{}
                             completionHandler:nil];
}

#pragma mark - Navigation to Sub-pages

- (void)showLayoutSettings {
    ModernSettingsPageViewController* vc =
        [[ModernSettingsPageViewController alloc] initWithAccount:self.account
                                                          pageKey:@"general"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showTimelinesSettings {
    ModernSettingsPageViewController* vc =
        [[ModernSettingsPageViewController alloc] initWithAccount:self.account pageKey:@"timelines"];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)showDownloadsSettings {
    ModernSettingsPageViewController* vc =
        [[ModernSettingsPageViewController alloc] initWithAccount:self.account
                                                          pageKey:@"media_downloads"];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
