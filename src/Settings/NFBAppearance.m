//
//  NFBAppearance.m
//  呱呱助手 —— 鲜艳版设置界面样式
//

#import "Settings/NFBAppearance.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const void* kNFBCardViewKey = &kNFBCardViewKey;

UIColor* NFBAccentColor(void) {
    return [UIColor colorWithRed:0.42 green:0.28 blue:0.98 alpha:1.0];  // 紫
}

UIColor* NFBAccentForPage(NSString* pageKey) {
    if ([pageKey isEqualToString:@"general"]) {
        return [UIColor colorWithRed:0.42 green:0.28 blue:0.98 alpha:1.0];  // 紫
    }
    if ([pageKey isEqualToString:@"timelines"]) {
        return [UIColor colorWithRed:0.42 green:0.28 blue:0.98 alpha:1.0];  // 紫
    }
    if ([pageKey isEqualToString:@"media_downloads"]) {
        return [UIColor colorWithRed:0.42 green:0.28 blue:0.98 alpha:1.0];  // 紫
    }
    return NFBAccentColor();
}

void NFBStyleIconChip(UIImageView* iconView, UIColor* accent) {
    if (iconView == nil) {
        return;
    }
    iconView.backgroundColor = [accent colorWithAlphaComponent:0.16];
    iconView.layer.cornerRadius = 10.0;
    iconView.layer.cornerCurve = kCACornerCurveContinuous;
    iconView.clipsToBounds = YES;
    iconView.contentMode = UIViewContentModeCenter;
    iconView.tintColor = accent;
}

void NFBPrepareCardCell(UITableViewCell* cell) {
    if (cell == nil) {
        return;
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];

    UIView* card = [[UIView alloc] init];
    card.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection* traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
                   ? [UIColor colorWithWhite:0.15 alpha:1.0]
                   : [UIColor whiteColor];
    }];
    card.layer.cornerRadius = 18.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.55].CGColor;
    card.layer.shadowColor = NFBAccentColor().CGColor;
    card.layer.shadowOpacity = 0.16;
    card.layer.shadowRadius = 10.0;
    card.layer.shadowOffset = CGSizeMake(0, 4);

    UIView* selected = [[UIView alloc] init];
    selected.backgroundColor = [NFBAccentColor() colorWithAlphaComponent:0.10];
    selected.layer.cornerRadius = 18.0;
    selected.layer.cornerCurve = kCACornerCurveContinuous;

    cell.backgroundView = card;
    cell.selectedBackgroundView = selected;
    cell.multipleSelectionBackgroundView = selected;
    objc_setAssociatedObject(cell, kNFBCardViewKey, card, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

void NFBLayoutCardCell(UITableViewCell* cell) {
    UIView* card = objc_getAssociatedObject(cell, kNFBCardViewKey);
    if (card == nil) {
        card = cell.backgroundView;
    }
    if (card == nil) {
        return;
    }
    card.frame = UIEdgeInsetsInsetRect(cell.bounds, UIEdgeInsetsMake(5.0, 16.0, 5.0, 16.0));
    card.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:card.bounds cornerRadius:18.0].CGPath;

    UIView* selected = cell.selectedBackgroundView;
    if (selected != nil) {
        selected.frame = card.frame;
        selected.layer.cornerRadius = 18.0;
    }
}

void NFBInstallVividGradient(UIView* host, UIColor* accent) {
    if (host == nil) {
        return;
    }
    if (accent == nil) {
        accent = NFBAccentColor();
    }
    static const NSInteger kGradientTag = 0x6E666268;
    UIView* existing = [host viewWithTag:kGradientTag];
    [existing removeFromSuperview];

    UIView* gradientHost = [[UIView alloc] initWithFrame:host.bounds];
    gradientHost.tag = kGradientTag;
    gradientHost.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                    UIViewAutoresizingFlexibleHeight;
    gradientHost.userInteractionEnabled = NO;

    CAGradientLayer* layer = [CAGradientLayer layer];
    layer.frame = host.bounds;
    layer.colors = @[
        (id)[accent colorWithAlphaComponent:0.55].CGColor,
        (id)[accent colorWithAlphaComponent:0.22].CGColor,
        (id)[[UIColor systemBackgroundColor] colorWithAlphaComponent:0.0].CGColor
    ];
    layer.locations = @[ @0.0, @0.32, @0.72 ];
    layer.startPoint = CGPointMake(0.0, 0.0);
    layer.endPoint = CGPointMake(1.0, 1.0);
    [gradientHost.layer addSublayer:layer];

    // 顶部一抹高光，让鲜艳色块更有层次
    CAGradientLayer* glow = [CAGradientLayer layer];
    glow.frame = CGRectMake(0, 0, CGRectGetWidth(host.bounds), 180.0);
    glow.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.30].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    glow.startPoint = CGPointMake(0.0, 0.0);
    glow.endPoint = CGPointMake(0.0, 1.0);
    [gradientHost.layer addSublayer:glow];

    [host insertSubview:gradientHost atIndex:0];
}
