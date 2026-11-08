//
//  NFBAppearance.m
//  呱呱助手
//

#import "Settings/NFBAppearance.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

static const void* kNFBCardViewKey = &kNFBCardViewKey;

void NFBPrepareCardCell(UITableViewCell* cell) {
    if (cell == nil) {
        return;
    }
    cell.backgroundColor = [UIColor clearColor];
    cell.contentView.backgroundColor = [UIColor clearColor];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    UIView* card = [[UIView alloc] init];
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 16.0;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.borderWidth = 0.5;
    card.layer.borderColor = [UIColor colorWithWhite:0.5 alpha:0.12].CGColor;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.06;
    card.layer.shadowRadius = 6.0;
    card.layer.shadowOffset = CGSizeMake(0, 2);

    UIView* selected = [[UIView alloc] init];
    selected.backgroundColor = [UIColor tertiarySystemFillColor];
    selected.layer.cornerRadius = 16.0;
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
    card.frame = UIEdgeInsetsInsetRect(cell.bounds, UIEdgeInsetsMake(3.0, 16.0, 3.0, 16.0));

    UIView* selected = cell.selectedBackgroundView;
    if (selected != nil) {
        selected.frame = card.frame;
        selected.layer.cornerRadius = 16.0;
    }
}

void NFBInstallGradientBackground(UIView* host) {
    if (host == nil) {
        return;
    }
    static const NSInteger kGradientTag = 0x6E666267;
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
        (id)[UIColor colorWithRed:0.55 green:0.60 blue:1.00 alpha:0.10].CGColor,
        (id)[UIColor colorWithRed:0.45 green:0.85 blue:0.85 alpha:0.06].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    layer.locations = @[ @0.0, @0.45, @1.0 ];
    layer.startPoint = CGPointMake(0.0, 0.0);
    layer.endPoint = CGPointMake(0.35, 0.55);
    [gradientHost.layer addSublayer:layer];
    [host insertSubview:gradientHost atIndex:0];
}
