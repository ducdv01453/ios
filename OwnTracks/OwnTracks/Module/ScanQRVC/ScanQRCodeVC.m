//
//  ScanQRCodeVC.m
//  OwnTracks
//
//  Created by DucDV on 26/03/2024.
//

#import "ScanQRCodeVC.h"
#import <AVFoundation/AVFoundation.h>

@interface ScanQRCodeVC () <AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) IBOutlet UIView *maskLayerView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;

@property (strong, nonatomic) AVCaptureSession *session;

@end

@implementation ScanQRCodeVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CGRect previewRect = [self makePreviewRectWithFrame:self.view.frame];
    self.maskLayerView.layer.mask = [self makeMaskWithRect:previewRect inFrame: self.view.frame];

    [self startCameraSessionWithPreviewRect:previewRect];
}

#pragma mark - AVCaptureMetadataOutputObjects Delegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    for (AVMetadataObject *data in metadataObjects) {
        if (![data isKindOfClass:[AVMetadataMachineReadableCodeObject class]]) continue;
        
        NSString *qrCodeDataString = [(AVMetadataMachineReadableCodeObject *)data stringValue];
        if ([data.type isEqualToString:AVMetadataObjectTypeQRCode]) {
            NSURL *url = [NSURL URLWithString:qrCodeDataString];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                self.resultLabel.text = url.absoluteString;
                NSLog(@"%@", url);
            }
        }
    }
}

#pragma mark - Private

- (void)startCameraSessionWithPreviewRect:(CGRect)previewRect {
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.session = [[AVCaptureSession alloc] init];
    
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if (input) {
        [self.session addInput:input];
        
        AVCaptureMetadataOutput *output = [[AVCaptureMetadataOutput alloc] init];
        output.rectOfInterest = [self convertRectOfInterestWithRect:previewRect inFrame:self.view.frame];
        [self.session addOutput:output];
        [output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        [output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code]];
        
        AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
        previewLayer.frame = self.view.bounds;
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [self.view.layer insertSublayer:previewLayer atIndex:0];
       
        [self.session startRunning];
    } else {
        NSLog(@"error");
    }
}

- (CGRect)makePreviewRectWithFrame:(CGRect)frame {
    // Calculate the size so that the preview is square
    CGFloat width = frame.size.width / 1.5;
    CGSize size = CGSizeMake(width, width);
    CGPoint point = CGPointMake((frame.size.width - width) / 2, (frame.size.height - width) / 2);

    return CGRectMake(point.x, point.y, size.width, size.height);
}

- (CGRect)convertRectOfInterestWithRect:(CGRect)rect inFrame:(CGRect)frame {
    CGFloat y = (rect.origin.y + 0) / frame.size.height;
    CGFloat x = rect.origin.x / frame.size.width;
    CGFloat height = rect.size.height / frame.size.height;
    CGFloat width = rect.size.width / frame.size.width;

    // The origin of rectOfInterest is top and right.
    return CGRectMake(y, 1 - width - x, height, width);
}

- (CAShapeLayer *)makeMaskWithRect:(CGRect)rect inFrame:(CGRect)frame {
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRect:frame];
    [maskPath moveToPoint:rect.origin];
    [maskPath addLineToPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y)];
    [maskPath addLineToPoint:CGPointMake(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
    [maskPath addLineToPoint:CGPointMake(rect.origin.x, rect.origin.y + rect.size.height)];
    [maskPath addLineToPoint:rect.origin];
 
    CAShapeLayer *mask = [[CAShapeLayer alloc] init];
    mask.path = maskPath.CGPath;
    mask.fillRule = kCAFillRuleEvenOdd;
    mask.fillColor = [UIColor blackColor].CGColor;
    
    return mask;
}

@end
