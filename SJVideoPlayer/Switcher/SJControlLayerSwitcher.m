//
//  SJControlLayerSwitcher.m
//  SJVideoPlayerProject
//
//  Created by 畅三江 on 2018/6/1.
//  Copyright © 2018年 畅三江. All rights reserved.
//

#import "SJControlLayerSwitcher.h"
#if __has_include(<SJObserverHelper/NSObject+SJObserverHelper.h>)
#import <SJObserverHelper/NSObject+SJObserverHelper.h>
#else
#import "NSObject+SJObserverHelper.h"
#endif

NS_ASSUME_NONNULL_BEGIN
static NSString *const SJPlayerSwitchControlLayerUserInfoKey = @"SJPlayerSwitchControlLayerUserInfoKey";
static NSNotificationName const SJPlayerWillBeginSwitchControlLayerNotification = @"SJPlayerWillBeginSwitchControlLayerNotification";
static NSNotificationName const SJPlayerDidEndSwitchControlLayerNotification = @"SJPlayerDidEndSwitchControlLayerNotification";

@interface SJControlLayerSwitcherObsrever : NSObject<SJControlLayerSwitcherObsrever>
- (instancetype)initWithSwitcher:(id<SJControlLayerSwitcher>)switcher;
@end

@implementation SJControlLayerSwitcherObsrever
@synthesize playerWillBeginSwitchControlLayer = _playerWillBeginSwitchControlLayer;
@synthesize playerDidEndSwitchControlLayer = _playerDidEndSwitchControlLayer;
- (instancetype)initWithSwitcher:(id<SJControlLayerSwitcher>)switcher {
    self = [super init];
    if ( !self ) return nil;
    [self sj_observeWithNotification:SJPlayerWillBeginSwitchControlLayerNotification target:switcher usingBlock:^(SJControlLayerSwitcherObsrever *  _Nonnull self, NSNotification * _Nonnull note) {
        if ( self.playerWillBeginSwitchControlLayer ) self.playerWillBeginSwitchControlLayer(note.object, note.userInfo[SJPlayerSwitchControlLayerUserInfoKey]);
    }];
    
    [self sj_observeWithNotification:SJPlayerDidEndSwitchControlLayerNotification target:switcher usingBlock:^(SJControlLayerSwitcherObsrever *_Nonnull self, NSNotification * _Nonnull note) {
        if ( self.playerDidEndSwitchControlLayer ) self.playerDidEndSwitchControlLayer(note.object, note.userInfo[SJPlayerSwitchControlLayerUserInfoKey]);
    }];
    return self;
}
@end

@interface SJControlLayerSwitcher ()
@property (nonatomic, strong, readonly) NSMutableDictionary *map;
@property (nonatomic, weak, nullable) SJBaseVideoPlayer *videoPlayer;
@end

@implementation SJControlLayerSwitcher
@synthesize currentIdentifier = _currentIdentifier;
@synthesize previousIdentifier = _previousIdentifier;
@synthesize delegate = _delegate;

#ifdef DEBUG
- (void)dealloc {
    NSLog(@"%d - %s", (int)__LINE__, __func__);
}
#endif

- (instancetype)initWithPlayer:(__weak SJBaseVideoPlayer *)videoPlayer {
    self = [super init];
    if ( !self ) return nil;
    _videoPlayer = videoPlayer;
    _map = [NSMutableDictionary dictionary];
    _previousIdentifier = SJControlLayer_Uninitialized;
    _currentIdentifier = SJControlLayer_Uninitialized;
    return self;
}

- (id<SJControlLayerSwitcherObsrever>)getObserver {
    return [[SJControlLayerSwitcherObsrever alloc] initWithSwitcher:self];
}

- (void)switchControlLayerForIdentitfier:(SJControlLayerIdentifier)identifier {
    SJControlLayerCarrier *carrier_new = self.map[@(identifier)];
    NSParameterAssert(carrier_new);
    SJControlLayerCarrier *carrier_old = self.map[@(self.currentIdentifier)];
    if ( carrier_new == carrier_old ) return;
    [self _switchControlLayerWithOldcarrier:carrier_old newcarrier:carrier_new];
}

- (BOOL)switchToPreviousControlLayer {
    if ( self.previousIdentifier == SJControlLayer_Uninitialized ) return NO;
    if ( !self.videoPlayer ) return NO;
    [self switchControlLayerForIdentitfier:self.previousIdentifier];
    return YES;
}

- (void)addControlLayer:(SJControlLayerCarrier *)carrier {
    SJControlLayerCarrier *old = self.map[@(carrier.identifier)];
    
    /// Thanks @steven326
    /// https://github.com/changsanjiang/SJVideoPlayer/issues/40
    if ( old && (old.identifier == self.currentIdentifier) ) {
        /// 替换
        [self _switchControlLayerWithOldcarrier:old newcarrier:carrier];
    }

    [self.map setObject:carrier forKey:@(carrier.identifier)];
}

- (void)_switchControlLayerWithOldcarrier:(SJControlLayerCarrier *_Nullable )carrier_old newcarrier:(SJControlLayerCarrier *)carrier_new {
    NSParameterAssert(carrier_new);
    
    if ( [self.delegate respondsToSelector:@selector(switcher:shouldSwitchToControlLayer:)] ) {
        if ( ![self.delegate switcher:self shouldSwitchToControlLayer:carrier_new.identifier] )
            return;
    }
    
    _videoPlayer.controlLayerDataSource = nil;
    _videoPlayer.controlLayerDelegate = nil;
    [carrier_old.controlLayer exitControlLayer];
    
    // - begin
    [NSNotificationCenter.defaultCenter postNotificationName:SJPlayerWillBeginSwitchControlLayerNotification object:self userInfo:@{SJPlayerSwitchControlLayerUserInfoKey:carrier_new.controlLayer}];
    _videoPlayer.controlLayerDataSource = carrier_new.controlLayer;
    _videoPlayer.controlLayerDelegate = carrier_new.controlLayer;
    _previousIdentifier = _currentIdentifier;
    _currentIdentifier = carrier_new.identifier;
    [carrier_new.controlLayer restartControlLayer];
    // - end
    [NSNotificationCenter.defaultCenter postNotificationName:SJPlayerDidEndSwitchControlLayerNotification object:self userInfo:@{SJPlayerSwitchControlLayerUserInfoKey:carrier_new.controlLayer}];
}

- (void)deleteControlLayerForIdentifier:(SJControlLayerIdentifier)identifier {
    [self.map removeObjectForKey:@(identifier)];
}

- (nullable SJControlLayerCarrier *)controlLayerForIdentifier:(SJControlLayerIdentifier)identifier {
    return self.map[@(identifier)];
}
@end


@implementation SJControlLayerSwitcher (Deprecated)
- (void)switchControlLayerForIdentitfier:(SJControlLayerIdentifier)identifier toVideoPlayer:(__kindof SJBaseVideoPlayer *)videoPlayer __deprecated_msg("use `switchControlLayerForIdentitfier`;") {
    [self switchControlLayerForIdentitfier:identifier];
}
@end

SJControlLayerIdentifier SJControlLayer_Uninitialized = LONG_MAX;

NS_ASSUME_NONNULL_END
