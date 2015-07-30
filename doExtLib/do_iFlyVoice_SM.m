//
//  do_iFlyVoice_SM.m
//  DoExt_API
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_iFlyVoice_SM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"

#import "iflyMSC/IFlySetting.h"
#import "Definition.h"
#import "iflyMSC/IFlySpeechUtility.h"
#import "IFlyFlowerCollector.h"
#import "iflyMSC/iflyMSC.h"
#import "IATConfig.h"
#import "iflyMSC/iflyMSC.h"
#import "ISRDataHelper.h"
#import "doJsonHelper.h"
#import "TTSConfig.h"

@interface do_iFlyVoice_SM()<IFlySpeechRecognizerDelegate,IFlyRecognizerViewDelegate,IFlySpeechSynthesizerDelegate>

@property (nonatomic, strong) NSString *pcmFilePath;//音频文件路径
@property (nonatomic, strong) IFlySpeechRecognizer *iFlySpeechRecognizer;//不带界面的识别对象
@property (nonatomic, strong) IFlySpeechSynthesizer * iFlySpeechSynthesizer;
@property (nonatomic, strong) IFlyRecognizerView *iflyRecognizerView;//带界面的识别对象
@property (nonatomic, strong) IFlyDataUploader *uploader;//数据上传对象
@property (nonatomic, strong) NSString * result;
@property (nonatomic, assign) BOOL isCanceled;

@end

@implementation do_iFlyVoice_SM
{
    id<doIScriptEngine> _scritEngine;
    NSString *_callbackName;
    doInvokeResult *_invokeResult;
    
    NSMutableDictionary *_totalResult;
}
#pragma mark - 方法
#pragma mark - 同步异步方法的实现
//同步
//异步

- (void)open:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    //参数字典_dictParas
    _scritEngine = [parms objectAtIndex:1];
    //自己的代码实现
    
    _callbackName = [parms objectAtIndex:2];
    //回调函数名_callbackName
    _invokeResult = [[doInvokeResult alloc] init];
    //_invokeResult设置返回值

    _totalResult = [NSMutableDictionary dictionary];
    [_totalResult setObject:@"" forKey:@"result"];
    [_totalResult setObject:@"" forKey:@"spell"];
//    [_totalResult setObject:@"" forKey:@"errorMsg"];

    [self initialization];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startRecognizer];
    });
}
//同步
- (void)pause:(NSArray *)parms
{
    [_iFlySpeechSynthesizer pauseSpeaking];
}
- (void)resume:(NSArray *)parms
{
    [_iFlySpeechSynthesizer resumeSpeaking];
}
- (void)speak:(NSArray *)parms
{
    [self initialization];
    _scritEngine = [parms objectAtIndex:1];
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    NSString *speakText = [doJsonHelper GetOneText:_dictParas :@"text" :@""];
    NSString *speakRole = [doJsonHelper GetOneText:_dictParas :@"role" :@""];
    [self initSynthesizer:speakRole];
    _iFlySpeechSynthesizer.delegate = self;
    if (speakText.length <= 0) {

    }
    [_iFlySpeechSynthesizer startSpeaking:speakText];
}
- (void)stop:(NSArray *)parms
{
    //自己的代码实现
    [_iFlySpeechSynthesizer stopSpeaking];
}
- (void)startRecognizer
{
    if(_iflyRecognizerView == nil)
    {
        [self initRecognizer ];
    }
    
    //设置音频来源为麦克风
    [_iflyRecognizerView setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    
    //设置听写结果格式为json
    [_iflyRecognizerView setParameter:@"plain" forKey:[IFlySpeechConstant RESULT_TYPE]];
    
    //保存录音文件，保存在sdk工作路径中，如未设置工作路径，则默认保存在library/cache下
    [_iflyRecognizerView setParameter:@"asr.pcm" forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
    
    [_iflyRecognizerView start];
}

- (void)initRecognizer
{
    //单例模式，UI的实例
    if (_iflyRecognizerView == nil) {
        //UI显示剧中
        _iflyRecognizerView= [[IFlyRecognizerView alloc] initWithCenter:[UIApplication sharedApplication].keyWindow.center];
        
        [_iflyRecognizerView setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
        
        //设置听写模式
        [_iflyRecognizerView setParameter:@"iat" forKey:[IFlySpeechConstant IFLY_DOMAIN]];
        
    }
    _iflyRecognizerView.delegate = self;
    
    if (_iflyRecognizerView != nil) {
        IATConfig *instance = [IATConfig sharedInstance];
        //设置最长录音时间
        [_iflyRecognizerView setParameter:instance.speechTimeout forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
        //设置后端点
        [_iflyRecognizerView setParameter:instance.vadEos forKey:[IFlySpeechConstant VAD_EOS]];
        //设置前端点
        [_iflyRecognizerView setParameter:instance.vadBos forKey:[IFlySpeechConstant VAD_BOS]];
        //设置采样率，推荐使用16K
        [_iflyRecognizerView setParameter:instance.sampleRate forKey:[IFlySpeechConstant SAMPLE_RATE]];
        if ([instance.language isEqualToString:[IATConfig chinese]]) {
            //设置语言
            [_iflyRecognizerView setParameter:instance.language forKey:[IFlySpeechConstant LANGUAGE]];
            //设置方言
            [_iflyRecognizerView setParameter:instance.accent forKey:[IFlySpeechConstant ACCENT]];
        }else if ([instance.language isEqualToString:[IATConfig english]]) {
            //设置语言
            [_iflyRecognizerView setParameter:instance.language forKey:[IFlySpeechConstant LANGUAGE]];
        }
        //设置是否返回标点符号
        [_iflyRecognizerView setParameter:instance.dot forKey:[IFlySpeechConstant ASR_PTT]];
        
    }
}

- (void)initialization
{
    //设置sdk的工作路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    [IFlySetting setLogFilePath:cachePath];
    
    //创建语音配置,appid必须要传入，仅执行一次则可
    NSString *initString = [[NSString alloc] initWithFormat:@"appid=%@",APPID_VALUE];
    
    //所有服务启动前，需要确保执行createUtility
    [IFlySpeechUtility createUtility:initString];
}

#pragma mark - 设置合成参数
- (void)initSynthesizer:(NSString *)vcnName
{
    TTSConfig *instance = [TTSConfig sharedInstance];
    if (instance == nil) {
        return;
    }
    
    //合成服务单例
    if (_iFlySpeechSynthesizer == nil) {
        _iFlySpeechSynthesizer = [IFlySpeechSynthesizer sharedInstance];
    }
    
    _iFlySpeechSynthesizer.delegate = self;
    
    
    
    //设置语速1-100
    [_iFlySpeechSynthesizer setParameter:instance.speed forKey:[IFlySpeechConstant SPEED]];
    
    //设置音量1-100
    [_iFlySpeechSynthesizer setParameter:instance.volume forKey:[IFlySpeechConstant VOLUME]];
    
    //设置音调1-100
    [_iFlySpeechSynthesizer setParameter:instance.pitch forKey:[IFlySpeechConstant PITCH]];
    
    /**
     下面引擎类型无需设置
     设置引擎类型，本demo仅支持在线方式
     [_iFlySpeechSynthesizer setParameter:instance.engineType forKey:[IFlySpeechConstant ENGINE_TYPE]];
     ****/
    
    
    //设置采样率
    [_iFlySpeechSynthesizer setParameter:instance.sampleRate forKey:[IFlySpeechConstant SAMPLE_RATE]];
    
    
    //设置发音人
    instance.vcnName = vcnName;
    [_iFlySpeechSynthesizer setParameter:instance.vcnName forKey:[IFlySpeechConstant VOICE_NAME]];
    
}
#pragma -mark
#pragma mark IFlySpeechSynthesizerDelegate的代理方法
- (void)onCompleted:(IFlySpeechError *)error
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
    [self.EventCenter FireEvent:@"finished" :invokeResult];
}

- (void)onSpeakBegin
{
    doInvokeResult *invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
    [self.EventCenter FireEvent:@"begin" :invokeResult];
}
//- (void)onSpeakPaused
//{
//    doInvokeResult *invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
//    [self.EventCenter FireEvent:@"paused" :invokeResult];
//}
//- (void)onSpeakResumed
//{
//    doInvokeResult *invokeResult = [[doInvokeResult alloc]init:self.UniqueKey];
//    [self.EventCenter FireEvent:@"resumed" :invokeResult];
//}

#pragma mark - recognizer delegate

/**
 开始识别回调
 ****/
- (void) onBeginOfSpeech
{
    NSLog(@"onBeginOfSpeech");
}

/**
 停止录音回调
 ****/
- (void) onEndOfSpeech
{
    NSLog(@"onEndOfSpeech");
}

/**
 听写结束回调（注：无论听写是否正确都会回调）
 error.errorCode =
 0     听写正确
 other 听写出错
 ****/
- (void) onError:(IFlySpeechError *) error
{
    NSLog(@"%s",__func__);
    NSString *text ;
    if ([IATConfig sharedInstance].haveView == YES ) {
        
        if (self.isCanceled) {
            text = @"识别取消";
            
        } else if (error.errorCode == 0 ) {
            if (_result.length == 0) {
                text = @"无识别结果";
            }else {
                text = @"";
            }
        }else {
            text = [NSString stringWithFormat:@"发生错误：%d %@", error.errorCode,error.errorDesc];
            NSLog(@"%@",text);
            [_invokeResult SetError:error.description];
        }
    }else {
        NSLog(@"errorCode:%d",[error errorCode]);
        text = @"";
        [_invokeResult SetError:error.description];
    }
    
    [_invokeResult SetResultNode:_totalResult];
    [_scritEngine Callback:_callbackName :_invokeResult];
}

- (void)onResults:(NSArray *)results isLast:(BOOL)isLast
{
    
    NSMutableString *resultString = [[NSMutableString alloc] init];
    NSDictionary *dic = results[0];
    for (NSString *key in dic) {
        [resultString appendFormat:@"%@",key];
    }
    _result =[NSString stringWithFormat:@"%@",resultString];
    NSString * resultFromJson =  [ISRDataHelper stringFromJson:resultString];
    
    if (isLast){
        NSLog(@"听写结果(json)：%@测试",  self.result);
    }
    NSLog(@"resultFromJson=%@",resultFromJson);
}

#pragma mark - IFlyRecognizerViewDelegate method
- (void)onResult:(NSArray *)resultArray isLast:(BOOL)isLast
{
    NSMutableString *result = [[NSMutableString alloc] init];
    NSDictionary *dic = [resultArray objectAtIndex:0];
    for (NSString *key in dic) {
        [result appendFormat:@"%@",key];
    }
    _result =[NSString stringWithFormat:@"%@",result];
    NSMutableString *pinyin = [result mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)pinyin, NULL, kCFStringTransformMandarinLatin, NO);
    CFStringTransform((__bridge CFMutableStringRef)pinyin, NULL, kCFStringTransformStripDiacritics, NO);
    
    NSString *re = [NSString stringWithFormat:@"%@%@",[_totalResult objectForKey:@"result"], result];
    NSString *spell = [NSString stringWithFormat:@"%@%@",[_totalResult objectForKey:@"spell"], pinyin];
    [_totalResult setObject:re forKey:@"result"];
    [_totalResult setObject:spell forKey:@"spell"];

    NSLog(@"result  =%@",result);
}


@end