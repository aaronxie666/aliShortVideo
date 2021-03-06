//
//  AliyunTimelineView.m
//  QPSDKCore
//
//  Created by Vienta on 2016/11/25.
//  Copyright © 2016年 lyle. All rights reserved.
//  此类复杂

#import "AliyunTimelineView.h"
#import "AliyunTimelineItemCell.h"
#import <AVFoundation/AVFoundation.h>
#import "AliAssetImageGenerator.h"
#import <AliyunVideoSDKPro/AliyunEffectFilter.h>

typedef NS_ENUM(NSUInteger, kVideoDirection) {
    kVideoDirectionUnkown = 0,
    kVideoDirectionPortrait,
    kVideoDirectionPortraitUpsideDown,
    kVideoDirectionLandscapeRight,
    kVideoDirectionLandscapeLeft,
};


//#define ITEMS_PER_SEGMENT 8
//#define THRESHOLD 20.0

const CGFloat PINCH_THRESHOLD = 50.0;
const CGFloat DELTA_X = 2.0;

typedef NS_ENUM(NSUInteger, kSpaceType) {
    kSpaceTypeCollectionViewLeading = 0,
    kSpaceTypeCollectionViewTrailing,
    kSpaceTypeLeftPinchView,
    kSpaceTypeRightPinchView
};

typedef NS_ENUM(NSUInteger, kRunDirection) {
    kRunDirectionLeft = 0,
    kRunDirectionRight
};

@interface AliyunTimelineView ()

@property (nonatomic, assign) CGFloat itemWidth;
@property (nonatomic, assign) CGFloat itemHeight;
@property (nonatomic, assign) CGFloat totalItemsWidth;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *photoItems;
@property (nonatomic, assign) CGFloat videoDuration;
@property (nonatomic, strong) UIView *indicator;
@property (nonatomic, strong) UIImageView *leftPinchView;
@property (nonatomic, strong) UIImageView *rightPinchView;
@property (nonatomic, strong) UIImageView *pinchBackgroudView;
@property (nonatomic, assign) CGFloat segment;
@property (nonatomic, assign) CGFloat singleItemDuration;
@property (nonatomic, copy) NSArray *photoCounts;
@property (nonatomic, assign) NSInteger photosPersegment;
@property (nonatomic, assign) CGFloat leftPinchTime;
@property (nonatomic, assign) CGFloat rightPinchTime;
@property (nonatomic, strong) NSMutableArray *timelinePercentItems;
@property (nonatomic, strong) NSMutableArray *timelineItems;
@property (nonatomic, strong) NSMutableArray *timelinePercentFilterItems;
@property (nonatomic, strong) NSMutableArray *timelineFilterItems;
@property (nonatomic, strong) NSMutableArray *timelineTimeFilterItems;
@property (nonatomic, strong) NSMutableArray *timelinePercentTimeFilterItems;
@property (nonatomic, strong) NSMutableDictionary *rotateDict;
@property (nonatomic, strong) NSMutableDictionary *durationDict;
@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;

@end

@implementation AliyunTimelineView
{
    BOOL _isDragging;
    BOOL _isDecelerate;
    CGFloat _leftPinchWidth;
    CGFloat _rightPinchWidth;
    UIImageView *_selectedPinchImageView;
    NSTimer *_scheduleTimer;
    AliyunTimelineItem *_currentItem;
    AliAssetImageGenerator *_generator;
}

#pragma mark - Update

- (void)setNeedDisplaySlider
{
    if (!_currentItem) {
        return;
    }
    [self setSliderEditStatus:YES];
    [self sliderPositionWithBeginTime:_currentItem.startTime endTime:_currentItem.endTime];
}

- (void)setNeedsUpdateGreyViews
{
    [self generateTimelinePercentItems];
}

- (void)setNeedsUpdatePinch
{
    [self setNeedsUpdateLeftPinch];
    [self setNeedsUpdateRightPinch];
}

- (void)setNeedsUpdatePinchBackgroudView
{
    self.pinchBackgroudView.frame = CGRectMake(self.leftPinchView.frame.origin.x+4, 0, self.rightPinchView.frame.origin.x - self.leftPinchView.frame.origin.x + _rightPinchWidth-6, self.itemHeight);
}

- (void)setNeedsUpdateLeftPinch
{
    CGFloat xp = [self transformOffsetPointOfSelfFromTime:self.leftPinchTime];
    CGRect leftPinchFrame = self.leftPinchView.frame;
    leftPinchFrame.origin.x = xp - _leftPinchWidth;
//    NSLog(@"缩略图滑动测试Before：%@",NSStringFromCGRect(self.leftPinchView.frame));
//    NSLog(@"缩略图滑动测试After：%@",NSStringFromCGRect(leftPinchFrame));
    self.leftPinchView.frame = leftPinchFrame;
}

- (void)setNeedsUpdateRightPinch
{
    CGFloat xp = [self transformOffsetPointOfSelfFromTime:self.rightPinchTime];
    CGRect rightPinchFrame = self.rightPinchView.frame;
    rightPinchFrame.origin.x = xp;
    self.rightPinchView.frame = rightPinchFrame;
}

- (void)setSliderEditStatus:(BOOL)isEdit
{
    if (isEdit) {
        self.leftPinchView.hidden = self.rightPinchView.hidden = self.pinchBackgroudView.hidden = NO;
    } else {
        self.leftPinchView.hidden = self.rightPinchView.hidden = self.pinchBackgroudView.hidden = YES;
    }
}

- (void)sliderPositionWithBeginTime:(CGFloat)beginTime endTime:(CGFloat)endTime
{
    self.leftPinchTime = beginTime;
    self.rightPinchTime = endTime;
    [self setNeedsUpdatePinch];
}

//将时间转化为相对于collectionview上的长度
- (CGFloat)transformOffsetPointOfCollectionViewFromTime:(CGFloat)time
{
    CGFloat offset = time / self.videoDuration *(self.photoCounts.count * self.itemWidth);
    
    if (self.actualDuration == 0) {
        self.actualDuration = self.videoDuration;
    }
    offset /= (self.actualDuration / self.videoDuration);

    return offset;
}

//将时间转化为在timelineView坐标上的x坐标
- (CGFloat)transformOffsetPointOfSelfFromTime:(CGFloat)time
{
    CGFloat offset = [self transformOffsetPointOfCollectionViewFromTime:time];
    CGFloat targetOffset = offset - self.collectionView.contentOffset.x;
    
    return targetOffset;
}

//将timelineView坐标上的x坐标转化为时间
- (CGFloat)transformTimeFromSelfOffset:(CGFloat)offset
{
    CGFloat timeOffset = [self transformCollectionViewOffsetFromSelfOffset:offset];
    CGFloat time = self.videoDuration * (timeOffset / (self.photoCounts.count * self.itemWidth));
    
    if (self.actualDuration == 0) {
        self.actualDuration = self.videoDuration;
    }
    time *= (self.actualDuration / self.videoDuration);
    
    return time;
}

//将timelineview x坐标 映射到collectionView上
- (CGFloat)transformCollectionViewOffsetFromSelfOffset:(CGFloat)offset
{
    CGFloat selfOffset = offset + self.collectionView.contentOffset.x;
    if (selfOffset < 0) {
        selfOffset = 0;
    }
    return selfOffset;
}

- (NSArray *)checkPasterExistBetween:(CGFloat)beginTime and:(CGFloat)endTime
{
    NSMutableArray *timelinePercents = [[NSMutableArray alloc] init];
    
    for (AliyunTimelineItem *item in self.timelineItems) {
        if (beginTime >= item.startTime && item.endTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            [timelinePercents addObject:timelinePercent];
        }
        if (beginTime >= item.startTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = 1.0f;
            [timelinePercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            [timelinePercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.startTime <= endTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.rightPercent = 1.0f;
            [timelinePercents addObject:timelinePercent];
        }
    }
    
    return timelinePercents;
}

- (NSArray *)checkFilterExistBetween:(CGFloat)beginTime and:(CGFloat)endTime {
    NSMutableArray *timelineFilterPercents = [[NSMutableArray alloc] init];
    
    for (AliyunTimelineFilterItem *item in self.timelineFilterItems) {
        if (beginTime >= item.startTime && item.endTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            [timelineFilterPercents addObject:timelinePercent];
        }
        if (beginTime >= item.startTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = 1.0f;
            timelinePercent.color = item.displayColor;
            [timelineFilterPercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            [timelineFilterPercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.startTime <= endTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            timelinePercent.rightPercent = 1.0f;
            [timelineFilterPercents addObject:timelinePercent];
        }
    }
    
    return timelineFilterPercents;
}

- (NSArray *)checkTimeFilterExistBetween:(CGFloat)beginTime and:(CGFloat)endTime {
    NSMutableArray *timelineTimeFilterPercents = [[NSMutableArray alloc] init];
    
    for (AliyunTimelineTimeFilterItem *item in self.timelineTimeFilterItems) {
        if (beginTime >= item.startTime && item.endTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            [timelineTimeFilterPercents addObject:timelinePercent];
        }
        if (beginTime >= item.startTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = 0.0f;
            timelinePercent.rightPercent = 1.0f;
            timelinePercent.color = item.displayColor;
            [timelineTimeFilterPercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.endTime <= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.rightPercent = (item.endTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            [timelineTimeFilterPercents addObject:timelinePercent];
        }
        if (item.startTime >= beginTime && item.startTime <= endTime && item.endTime >= endTime) {
            AliyunTimelinePercent *timelinePercent = [[AliyunTimelinePercent alloc] init];
            timelinePercent.leftPercent = (item.startTime - beginTime) / (endTime - beginTime);
            timelinePercent.color = item.displayColor;
            timelinePercent.rightPercent = 1.0f;
            [timelineTimeFilterPercents addObject:timelinePercent];
        }
    }
    
    return timelineTimeFilterPercents;
}

#pragma mark -Life Cycle
- (void)dealloc
{
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObservers];
    [self.imageGenerator cancelAllCGImageGeneration];
    [_generator cancel];
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.itemWidth = frame.size.height;
        self.itemHeight = frame.size.height;
    }
    return self;
}

- (void)setMediaClips:(NSArray<AliyunTimelineMediaInfo *> *)clips segment:(CGFloat)segment photosPersegent:(NSInteger)photos {
    self.segment = segment;
    
    self.photosPersegment = photos;
    if (photos <= 0) {
        self.photosPersegment = 8;
    }
    
    [self setupSubviews];
    [self setSliderEditStatus:NO];
    [self generateImagesWithMediaInfoClips:clips rotate:0];
    [self generateTimelinePercentItems];
    
    [self addObservers];
}

- (void)setupSubviews
{
    UICollectionViewFlowLayout *flowLayout = [[UICollectionViewFlowLayout alloc] init];
    flowLayout.sectionInset = UIEdgeInsetsMake(0, 0, 0, 0);
    flowLayout.minimumInteritemSpacing = 0;
    flowLayout.minimumLineSpacing = 0;
    flowLayout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    flowLayout.itemSize = CGSizeMake(self.itemWidth, self.itemHeight);
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) collectionViewLayout:flowLayout];
    self.collectionView.delegate = (id)self;
    self.collectionView.dataSource = (id)self;
    self.collectionView.backgroundColor = [UIColor clearColor];
    self.collectionView.showsHorizontalScrollIndicator = NO;
    self.collectionView.showsVerticalScrollIndicator = NO;
    self.collectionView.alwaysBounceHorizontal = YES;
    [self addSubview:self.collectionView];
    self.collectionView.contentInset = UIEdgeInsetsMake(0, CGRectGetMidX(self.bounds), 0, CGRectGetMidX(self.bounds));
    [self.collectionView registerClass:[AliyunTimelineItemCell class] forCellWithReuseIdentifier:@"AliyunTimelineItemCell"];
    
    
    self.indicator = [[UIView alloc] initWithFrame:CGRectMake(0, -8, 4, CGRectGetHeight(self.bounds)+16)];
    self.indicator.backgroundColor = AlivcOxRGB(0xfcc937);
    [self addSubview:self.indicator];
    CGPoint indicatorCenter = self.indicator.center;
    indicatorCenter.x = CGRectGetMidX(self.bounds);
    self.indicator.center = indicatorCenter;
    
    _leftPinchWidth = 30.0 / 2;
    
    NSString *leftPinchImageName = self.leftPinchImageName;
    if (!leftPinchImageName || [leftPinchImageName isEqualToString:@""]) {
        leftPinchImageName = @"timeLine_cut_sweep_right";
    }
    
    UIImage *leftPinchImage = [AlivcImage imageNamed:leftPinchImageName];//37*84
    self.leftPinchView = [[UIImageView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.bounds), -2, _leftPinchWidth, self.itemHeight+4)];
    self.leftPinchView.image = leftPinchImage;
    self.leftPinchView.userInteractionEnabled = YES;
    [self addSubview:self.leftPinchView];
    
    NSString *rightPinchImageName = self.rightPinchImageName;
    if (!rightPinchImageName || [rightPinchImageName isEqualToString:@""]) {
        rightPinchImageName = @"timeLine_cut_sweep_right";
    }
    
    _rightPinchWidth = 30.0 / 2;
    UIImage *rightPinchImage = [AlivcImage imageNamed:rightPinchImageName];//36.0*84.0
    self.rightPinchView = [[UIImageView alloc] initWithFrame:CGRectMake(CGRectGetMidX(self.bounds) + self.itemWidth, -2, _rightPinchWidth, self.itemHeight+4)];
    self.rightPinchView.image = rightPinchImage;
    self.rightPinchView.userInteractionEnabled = YES;
    [self addSubview:self.rightPinchView];
    
  
    NSString *pinchBgImageName = self.pinchBgImageName;
    if (!pinchBgImageName || [pinchBgImageName isEqualToString:@""]) {
        pinchBgImageName = @"paster_time_edit_slider_bg";
    }
    
    UIImage *pinchBgImage = [AlivcImage imageNamed:pinchBgImageName] ;
    self.pinchBackgroudView = [[UIImageView alloc] initWithFrame:CGRectMake(self.leftPinchView.frame.origin.x+2, 0, self.rightPinchView.frame.origin.x - self.leftPinchView.frame.origin.x + _rightPinchWidth-6, self.itemHeight)];
    self.pinchBackgroudView.image = pinchBgImage;
//    self.pinchBackgroudView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:.2];
    self.pinchBackgroudView.backgroundColor = AlivcOxRGBA(0x3CF2FF, 0.7);
    [self insertSubview:self.pinchBackgroudView belowSubview:self.leftPinchView];
}

-(void)willMoveToSuperview:(UIView *)newSuperview {
    if (newSuperview == nil) {
        [self.imageGenerator cancelAllCGImageGeneration];
        [_generator cancel];
    }
}

- (void)updateTimelineViewAlpha:(CGFloat)alpha {
    
    self.backgroundColor = [UIColor clearColor];
    self.collectionView.backgroundColor = rgba(35, 42, 66, 0.5);
}

- (void)setIndicatorColor:(UIColor *)indicatorColor
{
    _indicatorColor = indicatorColor;
    self.indicator.backgroundColor = indicatorColor;
}

-(void)setPinchBgColor:(UIColor *)pinchBgColor {
    _pinchBgColor = pinchBgColor;
    self.pinchBackgroudView.backgroundColor = pinchBgColor;
}


- (void)generateTimelinePercentItems
{
    [self.timelinePercentItems removeAllObjects];
    [self.timelinePercentFilterItems removeAllObjects];//WARNING
    [self.timelinePercentTimeFilterItems removeAllObjects];
    
    CGFloat itemDuration = self.videoDuration / [self.photoCounts count];
    
    for (NSInteger idx = 1; idx <= self.photoCounts.count; idx++) {
        
        CGFloat mappedBeginTime = itemDuration * (idx - 1);
        CGFloat mappedEndTime = itemDuration * idx;
        
        if (idx == [self.photoCounts count]) {
            if (mappedEndTime > self.videoDuration) {
                mappedEndTime = self.videoDuration;
            }
        }
        
        if (self.actualDuration == 0) {
            self.actualDuration = self.videoDuration;
        }
        mappedBeginTime *= (self.actualDuration / self.videoDuration);
        mappedEndTime *= (self.actualDuration / self.videoDuration);
        
        NSArray *timelinePercents = [self checkPasterExistBetween:mappedBeginTime and:mappedEndTime];
        [self.timelinePercentItems addObject:timelinePercents];
        
        NSArray *timelineFilterPercents = [self checkFilterExistBetween:mappedBeginTime and:mappedEndTime];
        [self.timelinePercentFilterItems addObject:timelineFilterPercents];
        
        NSArray *timelineTimeFilterPercents = [self checkTimeFilterExistBetween:mappedBeginTime and:mappedEndTime];
        [self.timelinePercentTimeFilterItems addObject:timelineTimeFilterPercents];
    }
    [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)addGenateImage:(UIImage *)image
{
    [self.photoItems addObject:image];
    [self.collectionView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)addObservers
{
    [self.leftPinchView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:NULL];
    [self.rightPinchView addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)removeObservers
{
    [self.leftPinchView removeObserver:self forKeyPath:@"frame"];
    [self.rightPinchView removeObserver:self forKeyPath:@"frame"];
}

- (CGFloat)getCurrentTime
{
    CGFloat offsetPoint = self.indicator.center.x + self.collectionView.contentOffset.x; //中间指针距离第一张图片的偏移量
    if (offsetPoint < 0) {
        offsetPoint = 0;
    } else if (offsetPoint > self.totalItemsWidth) {
        offsetPoint = self.totalItemsWidth;
    }
    
    CGFloat timeFromOffset = [self timeWithOffset:offsetPoint];
    return timeFromOffset;
}

- (void)seekToTime:(CGFloat)time
{
    if (_isDragging || _isDecelerate || self.videoDuration <= 0) {
        return;
    }
    
    if (self.actualDuration == 0) {
        self.actualDuration = self.videoDuration;
    }
//    NSLog(@"seekToTime:%f",time);
    CGFloat mappedTime = (self.videoDuration / self.actualDuration) * time;
//    NSLog(@"mappedTime:%f",mappedTime);
    CGFloat offset = [self offsetWithTime:mappedTime];
//    NSLog(@"offset:%f",offset);
    CGFloat centerX =offset - self.indicator.center.x;
//    NSLog(@"centerX:%f",centerX);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.collectionView.contentOffset = CGPointMake(centerX, self.collectionView.contentOffset.y);
    });
}

- (void)cancel
{
    [self.collectionView setContentOffset:self.collectionView.contentOffset animated:NO];
    _isDragging = NO;
    _isDecelerate = NO;
}

- (void)previewAction
{
    [self allPasterviewsEndEited];
}

- (void)addTimelineItem:(AliyunTimelineItem *)timelineItem
{
    [self.timelineItems addObject:timelineItem];
    [self setNeedsUpdateGreyViews];
}

- (void)removeTimelineItem:(AliyunTimelineItem *)timelineItem
{
    [self.timelineItems removeObject:timelineItem];
    [self allPasterviewsEndEited];
}

- (void)editTimelineItem:(AliyunTimelineItem *)timelineItem
{
    _currentItem = timelineItem;
    [self setNeedDisplaySlider];
}

- (void)editTimelineComplete
{
    _currentItem = nil;
    [self allPasterviewsEndEited];
}

- (AliyunTimelineItem *)getTimelineItemWithOjb:(id)obj
{
    __block AliyunTimelineItem *targetItem = nil;
    
    [self.timelineItems enumerateObjectsUsingBlock:^(AliyunTimelineItem *item, NSUInteger idx, BOOL * _Nonnull stop) {
        if([item.obj isEqual:obj]) {
            targetItem = item;
            *stop = YES;
        }
    }];
    
    return targetItem;
}

- (void)addTimelineFilterItem:(AliyunTimelineFilterItem *)filterItem {
    [self.timelineFilterItems addObject:filterItem];
    [self setNeedsUpdateGreyViews];
}

- (void)updateTimelineFilterItems:(AliyunTimelineFilterItem *)filterItem {
    if ([self.timelineFilterItems containsObject:filterItem] == NO) {
        [self.timelineFilterItems addObject:filterItem];
    }
    [self setNeedsUpdateGreyViews];
}

- (void)removeTimelineFilterItem:(AliyunTimelineFilterItem *)filterItem {
    [self.timelineFilterItems removeObject:filterItem];
    [self setNeedsUpdateGreyViews];
}

- (void)removeLastFilterItemFromTimeline {
    [self.timelineFilterItems removeLastObject];
    [self setNeedsUpdateGreyViews];
}

- (void)removeAllFilterItemFromTimeline {
    [self.timelineFilterItems removeAllObjects];
    [self setNeedsUpdateGreyViews];
}

-(void)removeFilterItemFormTimelineBy:(NSString*)path{
    for (int i=0; i<self.timelineFilterItems.count;i++) {
        AliyunTimelineTimeFilterItem *item = [self.timelineFilterItems objectAtIndex:i];
        if (item.obj && [item.obj isKindOfClass:AliyunEffectFilter.class]) {
            AliyunEffectFilter *filter = item.obj;
            if ([filter.path containsString:path]) {
                [self.timelineFilterItems removeObject:item];
                i--;
            }
        }
    }
    [self setNeedsUpdateGreyViews];
}

- (void)addTimelineTimeFilterItem:(AliyunTimelineTimeFilterItem *)timeFilterItem
{
    [self.timelineTimeFilterItems addObject:timeFilterItem];
    [self setNeedsUpdateGreyViews];
}

- (void)removeTimelineTimeFilterItem:(AliyunTimelineTimeFilterItem *)timeFilterItem
{
    [self.timelineTimeFilterItems removeObject:timeFilterItem];
    [self setNeedsUpdateGreyViews];
}

- (void)removeAllTimelineTimeFilterItem {
    [self.timelineTimeFilterItems removeAllObjects];
    [self setNeedsUpdateGreyViews];
}

#pragma mark - Notification

- (void)allPasterviewsEndEited
{
    _currentItem = nil;
    [self setSliderEditStatus:NO];
    [self setNeedsUpdateGreyViews];
}

#pragma mark - Observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    [self setNeedsUpdatePinchBackgroudView];
}

#pragma mark - Touches
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = (UITouch *)[touches anyObject];
    CGPoint point = [touch locationInView:self];
    
    CGRect leftPinchFrame = self.leftPinchView.frame;
    CGRect rightPinchFrame = self.rightPinchView.frame;
    
    CGRect leftPinchTouchFrame = leftPinchFrame;
    CGPoint leftPinchTouchCenter = self.leftPinchView.center;
    leftPinchTouchFrame.size.width += 30;
    leftPinchTouchFrame.origin.x = leftPinchTouchCenter.x - leftPinchTouchFrame.size.width / 2;
    
    CGRect rightPinchTouchFrame = rightPinchFrame;
    CGPoint rightPinchTouchCenter = self.rightPinchView.center;
    rightPinchTouchFrame.size.width += 30;
    rightPinchTouchFrame.origin.x = rightPinchTouchCenter.x - rightPinchTouchFrame.size.width / 2;
    
    
    if (self.leftPinchView.hidden == NO) {
        
        if (CGRectContainsPoint(leftPinchTouchFrame, point)) {
            _selectedPinchImageView = self.leftPinchView;
        }
        
        if (CGRectContainsPoint(rightPinchTouchFrame, point)) {
            _selectedPinchImageView = self.rightPinchView;
        }
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = (UITouch *)[touches anyObject];
    CGPoint newPoint = [touch locationInView:self];
    CGPoint prePoint = [touch previousLocationInView:self];
//    NSLog(@"========NewPoint%@",NSStringFromCGPoint(newPoint));
//    NSLog(@"======PrePoint%@",NSStringFromCGPoint(prePoint));
    CGRect selectPinchViewFrame = _selectedPinchImageView.frame;
    CGFloat time = [self transformTimeFromSelfOffset:newPoint.x];
    if (self.delegate && [self.delegate respondsToSelector:@selector(timelineEditDraggingAtTime:)]) {
        [self.delegate timelineEditDraggingAtTime:time];
    }
    if (_selectedPinchImageView == self.leftPinchView) {
        
        if (newPoint.x > prePoint.x) {
            [self destroy];
        }
        CGFloat collectionLeadingPointX = [self timelineXpointSpace:kSpaceTypeCollectionViewLeading];
        if (newPoint.x >= collectionLeadingPointX - _leftPinchWidth && newPoint.x >= PINCH_THRESHOLD - _leftPinchWidth) {
            //左滑动块未达到左侧阀值且未到视频起点  左侧滑块继续往左滑动 右侧滑块不动
            selectPinchViewFrame.origin.x = newPoint.x;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        } else if (newPoint.x > collectionLeadingPointX && newPoint.x < PINCH_THRESHOLD - _leftPinchWidth) {
            //左滑动块达到左侧阀值但未到视频起点  左侧滑块保持不动，collectview需向右滑动 且右边滑动块也要跟着collection
            selectPinchViewFrame.origin.x = PINCH_THRESHOLD - _leftPinchWidth;
            _selectedPinchImageView.frame = selectPinchViewFrame;
            [self runWithDirection:kRunDirectionLeft];
        } else if (newPoint.x < collectionLeadingPointX - _leftPinchWidth && newPoint.x > PINCH_THRESHOLD) {
            //左滑动块未达到左侧阀值但已到视频起点  左侧滑块不动 collectionView不动 右侧滑竿不动
            selectPinchViewFrame.origin.x = collectionLeadingPointX - _leftPinchWidth;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        }
        
        CGFloat delta = [self minDurationFromItem];
        
        if (_selectedPinchImageView.frame.origin.x + _leftPinchWidth > self.rightPinchView.frame.origin.x - delta) {
            selectPinchViewFrame.origin.x = self.rightPinchView.frame.origin.x - _leftPinchWidth - delta;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        }
        [self setNeedsUpdateRightPinch];
    } else if (_selectedPinchImageView == self.rightPinchView) {
        if (newPoint.x < prePoint.x) {
            [self destroy];
        }
        CGFloat collectionTrailingPointX = [self timelineXpointSpace:kSpaceTypeCollectionViewTrailing];
        if (newPoint.x <= CGRectGetWidth(self.bounds) - PINCH_THRESHOLD && newPoint.x <= collectionTrailingPointX ) {
            //右滑动块未达到右侧阀值且未到达视频终点  右侧滑动块继续向右滑动 左侧滑块不动
            selectPinchViewFrame.origin.x = newPoint.x;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        } else if (newPoint.x > CGRectGetWidth(self.bounds) - PINCH_THRESHOLD && newPoint.x < collectionTrailingPointX) {
            //右滑块达到右侧阀值但未到视频结束 右滑动块不动 collectionview向左滑动 且做滑动块要跟着向左滑动
            selectPinchViewFrame.origin.x = CGRectGetWidth(self.bounds) - PINCH_THRESHOLD;
            _selectedPinchImageView.frame = selectPinchViewFrame;
            
            [self runWithDirection:kRunDirectionRight];
        } else if (newPoint.x < CGRectGetWidth(self.bounds) - PINCH_THRESHOLD && newPoint.x > collectionTrailingPointX) {
            //右滑块未到达阀值但已到达视频结束 右滑块不动 collectionView不动
            selectPinchViewFrame.origin.x = collectionTrailingPointX;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        }
        CGFloat delta = [self minDurationFromItem];

        CGFloat selectedX = _selectedPinchImageView.frame.origin.x;
        CGFloat leftPinchX =self.leftPinchView.frame.origin.x + _leftPinchWidth + delta;
//        NSLog(@"selectedX:%f       leftPinchX:%f",selectedX,leftPinchX);
        if (selectedX < leftPinchX) {
            selectPinchViewFrame.origin.x = self.leftPinchView.frame.origin.x + _leftPinchWidth + delta;
            _selectedPinchImageView.frame = selectPinchViewFrame;
        }
        [self setNeedsUpdateLeftPinch];
    }
}

- (CGFloat)minDurationFromItem {
//    return [self offsetWithTime:_currentItem.minDuration];
    //如果这里有最小时长，当缩略图调整时间在结尾时会导致活动结束位置计算偏差，最小时长约大计算出来偏差越大，导致调整遮罩层滑出缩略图的BUG，所以这里最小时长暂且写成0，写成0不会影响当前功能。后期缩略图需要重写
    return [self offsetWithTime:0];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    
    CGFloat touchEndTime = 0;
    if (_selectedPinchImageView == self.rightPinchView) {
        self.rightPinchTime = [self transformTimeFromSelfOffset:self.rightPinchView.frame.origin.x];
        _currentItem.endTime = self.rightPinchTime;
        [self seekToTime:_currentItem.endTime];
        touchEndTime = _currentItem.endTime;
    } else if (_selectedPinchImageView == self.leftPinchView) {
        self.leftPinchTime = [self transformTimeFromSelfOffset:self.leftPinchView.frame.origin.x + _leftPinchWidth];
        _currentItem.startTime = self.leftPinchTime;
        [self seekToTime:_currentItem.startTime];
        touchEndTime = _currentItem.startTime;
    }
    
    _selectedPinchImageView = nil;
    [self destroy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsUpdatePinch];
        [self setNeedsUpdateGreyViews];
    });
    if (self.delegate && [self.delegate respondsToSelector:@selector(timelineDraggingTimelineItem:)]) {
        [self.delegate timelineDraggingTimelineItem:_currentItem];
    }
    if (self.actualDuration == 0) {
        self.actualDuration = self.videoDuration;
    }
    touchEndTime *= (self.actualDuration / self.videoDuration);
    
    [self.delegate timelineDraggingAtTime:touchEndTime];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    _selectedPinchImageView = nil;
    [self destroy];
}

- (void)collectionViewShouldScrollDirection:(NSTimer *)timer
{
    NSDictionary *userInfo = timer.userInfo;
    kRunDirection runDirection = [[userInfo objectForKey:@"runDirection"] integerValue];
    
    if (![self checkCollectionViewContentOffsetInAvailableSlider]) {
        [self destroy];
        
        if (runDirection == kRunDirectionLeft) {
            CGPoint offset = self.collectionView.contentOffset;
            offset.x = - (self.leftPinchView.frame.origin.x + _leftPinchWidth);
            self.collectionView.contentOffset = offset;
        }
        
        if (runDirection == kRunDirectionRight) {
            CGPoint offset = self.collectionView.contentOffset;
            offset.x = self.photoCounts.count * self.itemWidth - (CGRectGetWidth(self.bounds) - PINCH_THRESHOLD);
            self.collectionView.contentOffset = offset;
        }
        return;
    }
    
    CGPoint contentOffset = self.collectionView.contentOffset;
    if (runDirection == kRunDirectionLeft) {
        contentOffset.x -= DELTA_X;
    } else {
        contentOffset.x += DELTA_X;
    }
    
    self.collectionView.contentOffset = contentOffset;
    
    if (runDirection == kRunDirectionLeft) {
        [self setNeedsUpdateRightPinch];
    } else {
        [self setNeedsUpdateLeftPinch];
    }
}

- (BOOL)checkCollectionViewContentOffsetInAvailableSlider
{
    CGFloat timelineLeadingXPoint = [self timelineXpointSpace:kSpaceTypeCollectionViewLeading];
    CGFloat timelineTrailingXPoint = [self timelineXpointSpace:kSpaceTypeCollectionViewTrailing];
    CGFloat leftPinchXPoint = [self timelineXpointSpace:kSpaceTypeLeftPinchView];
    CGFloat rightPinchXPoint = [self timelineXpointSpace:kSpaceTypeRightPinchView];
    
    if (timelineLeadingXPoint > leftPinchXPoint + _leftPinchWidth) {
        return NO;
    }
    
    if (timelineTrailingXPoint < rightPinchXPoint) {
        return NO;
    }
    
    return YES;
}

- (void)runWithDirection:(kRunDirection)runDirection
{
    [self destroy];
    _scheduleTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60 target:self selector:@selector(collectionViewShouldScrollDirection:) userInfo:@{@"runDirection": @(runDirection)} repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:_scheduleTimer forMode:NSRunLoopCommonModes];
}

- (void)destroy
{
    [_scheduleTimer invalidate];
    _scheduleTimer = nil;
}

#pragma mark - UICollectionViewDelegate && UICollectionViewDataSource -
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.photoCounts count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    AliyunTimelineItemCell *timelineCell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AliyunTimelineItemCell" forIndexPath:indexPath];

    UIImage *image = nil;
    if (indexPath.row < self.photoItems.count) {
        image = [self.photoItems objectAtIndex:indexPath.row];
    }
    
    NSInteger idx = indexPath.row + 1; //当前所在的图片块index
    
    CGFloat itemDuration = self.videoDuration / [self.photoCounts count];
    
    CGFloat mappedBeginTime = itemDuration * (idx - 1);
    CGFloat mappedEndTime = itemDuration * idx;
    
    if (idx == [self.photoCounts count]) {
        if (mappedEndTime > self.videoDuration) {
            mappedEndTime = self.videoDuration;
        }
    }
    
    NSArray *timelinePercent = [self.timelinePercentItems objectAtIndex:indexPath.row];
    NSArray *timelineFilterPercent = [self.timelinePercentFilterItems objectAtIndex:indexPath.row];
    NSArray *timelineTimeFilterPercent = [self.timelinePercentTimeFilterItems objectAtIndex:indexPath.row];

    [timelineCell setMappedBeginTime:mappedBeginTime
                             endTime:mappedEndTime
                               image:image
                    timelinePercents:timelinePercent
              timelineFilterPercents:timelineFilterPercent
          timelineTimeFilterPercents:timelineTimeFilterPercent];
    
    return timelineCell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_isDecelerate || _isDragging) {
        CGFloat offsetPoint = self.indicator.center.x + self.collectionView.contentOffset.x; //中间指针距离第一张图片的偏移量
        if (offsetPoint < 0) {
            offsetPoint = 0;
        } else if (offsetPoint > self.totalItemsWidth) {
            offsetPoint = self.totalItemsWidth;
        }
        
        CGFloat timeFromOffset = [self timeWithOffset:offsetPoint];
        if (self.delegate && [self.delegate respondsToSelector:@selector(timelineDraggingAtTime:)]) {
            if (self.actualDuration == 0) {
                self.actualDuration = self.videoDuration;
            }
            timeFromOffset *= (self.actualDuration / self.videoDuration);
            [self.delegate timelineDraggingAtTime:timeFromOffset];
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(timelineCurrentTime: duration:)]) {
            CGFloat currentTime = [self getCurrentTime];
            if (self.actualDuration == 0) {
                self.actualDuration = self.videoDuration;
            }
            currentTime *= (self.actualDuration / self.videoDuration);
            
            [self.delegate timelineCurrentTime:currentTime duration:self.actualDuration];
        }
    });
}

- (CGFloat)timeWithOffset:(CGFloat)offset
{
    CGFloat time =  (offset / ([self.photoCounts count] * self.itemWidth) ) * self.videoDuration;
    return time;
}

- (CGFloat)offsetWithTime:(CGFloat)time
{
    CGFloat offset = (time / self.videoDuration) * (self.itemWidth * [self.photoCounts count]);
    return offset;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _isDragging = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(timelineBeginDragging)]) {
        [self.delegate timelineBeginDragging];
    }
    _currentItem = nil;
    [self setSliderEditStatus:NO];
    [self setNeedsUpdateGreyViews];
}
//拖动结束
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    _isDragging = NO;
    if (_isDragging == NO && _isDecelerate == NO) {
        
        CGFloat offsetPoint = self.indicator.center.x + self.collectionView.contentOffset.x; //中间指针距离第一张图片的偏移量
        if (offsetPoint < 0) {
            offsetPoint = 0;
        } else if (offsetPoint > self.totalItemsWidth) {
            offsetPoint = self.totalItemsWidth;
        }
        CGFloat timeFromOffset = [self timeWithOffset:offsetPoint];
        if (self.actualDuration == 0) {
            self.actualDuration = self.videoDuration;
        }
        timeFromOffset *= (self.actualDuration / self.videoDuration);
        
        if (decelerate) {
            [self.delegate timelineDraggingAtTime:timeFromOffset];
        }else {
           [self.delegate timelineEndDraggingAndDecelerate:timeFromOffset];
        }
    }
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
    _isDecelerate = YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _isDecelerate = NO;
    if (_isDecelerate == NO && _isDragging == NO) {
        CGFloat offsetPoint = self.indicator.center.x + self.collectionView.contentOffset.x; //中间指针距离第一张图片的偏移量
        if (offsetPoint < 0) {
            offsetPoint = 0;
        } else if (offsetPoint > self.totalItemsWidth) {
            offsetPoint = self.totalItemsWidth;
        }
        CGFloat timeFromOffset = [self timeWithOffset:offsetPoint];
        if (self.actualDuration == 0) {
            self.actualDuration = self.videoDuration;
        }
        timeFromOffset *= (self.actualDuration / self.videoDuration);
        
              
        [self.delegate timelineEndDraggingAndDecelerate:timeFromOffset];
    }
}

/**
 坐标转化  导航条作为参考系 进行其他控件的坐标转换
 */
- (CGFloat)timelineXpointSpace:(kSpaceType)spaceType
{
    if (spaceType == kSpaceTypeCollectionViewLeading) {
        return - self.collectionView.contentOffset.x;
    } else if (spaceType == kSpaceTypeCollectionViewTrailing) {
        return ( - self.collectionView.contentOffset.x + self.itemWidth * self.photoCounts.count);
    } else if (spaceType == kSpaceTypeLeftPinchView) {
        return self.leftPinchView.frame.origin.x;
    } else if (spaceType == kSpaceTypeRightPinchView) {
        return self.rightPinchView.frame.origin.x;
    }
    return NAN;
}

#pragma mark - Getter -
- (NSMutableArray *)photoItems
{
    if (!_photoItems) {
        _photoItems = [[NSMutableArray alloc] init];
    }
    return _photoItems;
}

- (NSMutableArray *)timelinePercentItems
{
    if (!_timelinePercentItems) {
        _timelinePercentItems = [[NSMutableArray alloc] init];
    }
    return _timelinePercentItems;
}

- (NSMutableArray *)timelinePercentFilterItems {
    if (!_timelinePercentFilterItems) {
        _timelinePercentFilterItems = [[NSMutableArray alloc] init];
    }
    return _timelinePercentFilterItems;
}

- (NSMutableArray *)timelinePercentTimeFilterItems {
    if (!_timelinePercentTimeFilterItems) {
        _timelinePercentTimeFilterItems = [[NSMutableArray alloc] init];
    }
    return _timelinePercentTimeFilterItems;
}

- (NSMutableArray *)timelineItems
{
    if (!_timelineItems) {
        _timelineItems = [[NSMutableArray alloc] init];
    }
    return _timelineItems;
}

- (NSMutableArray *)timelineFilterItems {
    if (!_timelineFilterItems) {
        _timelineFilterItems = [[NSMutableArray alloc] init];
    }
    return _timelineFilterItems;
}

- (NSMutableArray *)timelineTimeFilterItems {
    if (!_timelineTimeFilterItems) {
        _timelineTimeFilterItems = [[NSMutableArray alloc] init];
    }
    return _timelineTimeFilterItems;
}

- (void)generateImagesWithMediaInfoClips:(NSArray *)clips rotate:(NSInteger)rotate {
    _generator = [[AliAssetImageGenerator alloc] init];
    for (AliyunTimelineMediaInfo *info in clips) {
        if (info.mediaType == AliyunTimelineMediaInfoTypePhoto || info.mediaType == AliyunTimelineMediaInfoTypeGif) {
            [_generator addImageWithPath:info.path duration:info.duration animDuration:0];
        }else {
            [_generator addVideoWithPath:info.path startTime:info.startTime duration:info.duration animDuration:0];
        }
    }
    self.videoDuration = _generator.duration;
    CGFloat singleTime = self.segment / self.photosPersegment;// 一个图片的时间
    self.singleItemDuration = singleTime;
    NSMutableArray *timeValues = [[NSMutableArray alloc] init];
    int idx = 0;
    while (idx * singleTime < self.videoDuration) {
        double time = idx * singleTime;
        [timeValues addObject:@(time)];
        idx++;
    }
    self.photoCounts = timeValues;
//    NSLog(@"缩略图测试 图片数量:%ld",self.photoCounts.count);
    self.totalItemsWidth = self.itemWidth * [self.photoCounts count];
    _generator.imageCount = [self.photoCounts count];
    _generator.outputSize = CGSizeMake(200, 200);
    _generator.timePerImage = singleTime;
    __weak typeof(self)weakSelf = self;
    [_generator generateWithCompleteHandler:^(UIImage *image) {
        if (image) {
            [self addGenateImage:image];
//            NSLog(@"缩略图测试:添加图片");
            if (!weakSelf.coverImage) {
                weakSelf.coverImage = image;
            }
        }
    }];
}

- (void)stopSlid{
    [self.collectionView setContentOffset:self.collectionView.contentOffset animated:NO];
}


@end
