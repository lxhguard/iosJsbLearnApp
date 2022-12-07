#import "ViewController.h"
#import <JavaScriptCore/JavaScriptCore.h>

// 运行当前APP的设备屏幕宽度
#define SCREENWIDTH       [UIScreen mainScreen].bounds.size.width

@protocol JSObjcDelegate <JSExport>

- (void)getMsgFromFS:(NSString *)infoStr;

@end

@interface ViewController () <UIWebViewDelegate, JSObjcDelegate>

@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) JSContext *jsContext;
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation ViewController

#pragma mark - Life Circle
- (void)viewDidLoad {
    [super viewDidLoad];
        self.view.backgroundColor = [UIColor whiteColor];
        
        // （1）创建一个 Label 文本，用于接收前端的数据，并展示JSB数据
        _label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, SCREENWIDTH, 50)];
        _label.backgroundColor = [UIColor blueColor];
        _label.text = @"这里是 IOS 的标签，准备接受前端的消息";
        _label.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:_label];
        
        // （2）创建一个 Button 按钮，用于发送消息给前端
        UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(SCREENWIDTH / 2 - 100, 60, 200, 50)];
        button.backgroundColor = [UIColor blueColor];
        [button setTitle:@"尚未发送数据" forState:UIControlStateNormal];
        [button setTitle:@"已触发JSB" forState:UIControlStateHighlighted];
        [button addTarget:self action:@selector(btnClick:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:button];
    
        // （3）创建 Webview 链接本地 html 文件
        UIWebView *webview = [[UIWebView alloc]initWithFrame:CGRectMake(0, 200, SCREENWIDTH, 500)];
        webview.delegate = self;
        [self.view addSubview:webview];
        _webView = webview;
        NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:@"www"];
        NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
        [_webView loadHTMLString:htmlString baseURL: [[NSBundle mainBundle] bundleURL]];
}

/** 解析 JSON字符串 为 OC 对象  */
- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString {
    if (jsonString == nil) {
     return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
    if(err) {
        NSString *log = [NSString stringWithFormat:@"%d, %s | json解析失败：%@", __LINE__, __func__, err];
        return nil;
    }
    return dic;
}

/** 解析  OC 对象  为 JSON字符串 (这个暂时没用到，因为客户端--->前端 JSB数据直接扔OC对象，传输会自动转JSON字符串) */
- (NSString *)convertToJsonData:(NSDictionary *)dict
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString;

    if (!jsonData) {
        NSLog(@"%@",error);
    } else {
        jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
    }

    NSMutableString *mutStr = [NSMutableString stringWithString:jsonString];
    NSRange range = {0,jsonString.length};
    [mutStr replaceOccurrencesOfString:@" " withString:@"" options:NSLiteralSearch range:range];

    NSRange range2 = {0,mutStr.length};
    [mutStr replaceOccurrencesOfString:@"\n" withString:@"" options:NSLiteralSearch range:range2];
    return mutStr;
}

/** 按钮点击事件：JSB向前端发送数据。直接调用前端JS方法。  */
- (void)btnClick:(UIButton *)button {
    JSValue *getMsgFromIOS = self.jsContext[@"getMsgFromIOS"];

    NSDictionary *dict1 = [NSDictionary dictionaryWithObjectsAndKeys:@"我是来自客户端的数据",@"desc",@"客户端标题",@"title", nil];
    NSMutableDictionary* dict2 = [NSMutableDictionary dictionary];
    [dict2 setValue:@"change_fe_text" forKey:@"eventName"];
    [dict2 setValue:dict1 forKey:@"params"];

    [getMsgFromIOS callWithArguments:@[dict2]];
}

#pragma mark - UIWebViewDelegate
/** Webview 加载完成时，打通IOS、前端之间的数据通信
    前端角度：进行注入式JSB，即通过 WebView 提供的接口向 window 中注入对象或方法
    客户端角度：使用苹果推出的JavaScriptCore框架进行跨端通信
*/
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // JSContext：给JavaScript提供运行的上下文环境
    self.jsContext = [webView valueForKeyPath:@"documentView.webView.mainFrame.javaScriptContext"];
    self.jsContext[@"JSBridge"] = self;
    self.jsContext.exceptionHandler = ^(JSContext *context, JSValue *exceptionValue) {
        context.exception = exceptionValue;
        NSLog(@"IOS异常信息：%@", exceptionValue);
    };
}

// 自定义JSObjcDelegate协议，而且此协议必须遵守JSExport这个协议，自定义协议中的方法就是暴露给web页面的方法
#pragma mark - JSObjcDelegate

//  假设此方法是在子线程中执行的，线程名sub-thread
- (void)getMsgFromFS:(NSString *)infoStr {
    // 这句假设要在主线程中执行，线程名main-thread
    NSLog(@"getMsgFromFS infoStr:%@", infoStr);
        
    // 下面这两句代码最好还是要在子线程sub-thread中执行啊
    // 获取到照片之后在回调js的方法picCallback把图片传出去
    NSDictionary *info = [self dictionaryWithJsonString:infoStr];
    NSDictionary *params = info[@"params"];
    NSLog(@"getMsgFromFS params:%@", params);
    _label.text = params[@"desc"];

}



@end
