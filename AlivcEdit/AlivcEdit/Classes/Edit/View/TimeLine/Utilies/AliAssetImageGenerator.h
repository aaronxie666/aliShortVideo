//
//  AliAssetImageGenerator.h
//  AlivcSceneDemo
//
//  Created by Worthy on 2017/7/25.
//  Copyright © 2017年 Worthy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
typedef NS_ENUM(NSUInteger, AliAssetInfoType) {
    AliAssetInfoTypeVideo,
    AliAssetInfoTypeImage
};

@interface AliAssetInfo : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, assign) AliAssetInfoType type;
@property (nonatomic, assign) CGFloat startTime;
@property (nonatomic, assign) CGFloat duration;
@property (nonatomic, assign) CGFloat animDuration;

- (UIImage *)captureImageAtTime:(CGFloat)time outputSize:(CGSize)outputSize;
-(CGFloat)realDuration;

@end

@interface AliAssetImageGenerator : NSObject

@property (nonatomic) CGSize outputSize;
@property (nonatomic) NSInteger imageCount; //图片数量
@property (nonatomic, assign) CGFloat timePerImage; //2个图片的间隔时间
@property (nonatomic, assign) CGFloat duration;

- (void)addVideoWithPath:(NSString *)path startTime:(CGFloat)startTime duration:(CGFloat)duration animDuration:(CGFloat)animDuration;
- (void)addImageWithPath:(NSString *)path duration:(CGFloat)duration animDuration:(CGFloat)animDuration;
- (void)generateWithCompleteHandler:(void(^)(UIImage *))handler;
- (void)cancel;
/**
 获取视频缩略图

 @param videoURL 视频地址
 @param time 时间
 @return 封面
 */
+ (UIImage*)thumbnailImageForVideo:(NSURL *)videoURL atTime:(NSTimeInterval)time;


@end
