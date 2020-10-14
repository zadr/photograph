#import "PGViewController.h"

@import AVFoundation;

@interface PGViewController () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCaptureDeviceInput *input;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCapturePhotoOutput *output;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@end

@implementation PGViewController

- (id) init {
	if (!(self = [super init]))
		return nil;

	AVCaptureDeviceDiscoverySession *captureDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[ AVCaptureDeviceTypeBuiltInWideAngleCamera ] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
	AVCaptureDevice *camera = captureDiscoverySession.devices.firstObject;

	[camera lockForConfiguration:NULL];
	camera.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
	camera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
	[camera unlockForConfiguration];

	_input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:NULL];

	_session = [[AVCaptureSession alloc] init];
	_session.sessionPreset = AVCaptureSessionPresetPhoto;
	[_session addInput:_input];

	_output = [[AVCapturePhotoOutput alloc] init];
	[_output setPreparedPhotoSettingsArray:[NSArray arrayWithObjects:AVCapturePhotoSettings.photoSettings, self.rawSettings, nil]
						 completionHandler:^(BOOL prepared, NSError * _Nullable error) {
							 NSLog(@"prepared: %@ %@", @(prepared), error);
						 }];
	[_session addOutput:_output];

	return self;
}

- (BOOL) prefersStatusBarHidden {
	return YES;
}

- (void) viewDidLoad {
    [super viewDidLoad];

	[_session startRunning];

	self.videoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
	self.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
	self.videoPreviewLayer.frame = self.view.bounds;

	[self.view.layer addSublayer:self.videoPreviewLayer];

	UITapGestureRecognizer *doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeFocusPoint:)];
	doubleTapGestureRecognizer.numberOfTapsRequired = 2;
	[self.view addGestureRecognizer:doubleTapGestureRecognizer];

	UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(takePhotograph:)];
	[tapGestureRecognizer requireGestureRecognizerToFail:doubleTapGestureRecognizer];
	[self.view addGestureRecognizer:tapGestureRecognizer];

	UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(flipTorchMode)];
	swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp | UISwipeGestureRecognizerDirectionDown;
	[self.view addGestureRecognizer:swipeGestureRecognizer];
}

#pragma mark -

- (void) takePhotograph:(UITapGestureRecognizer *) tapGestureRecognizer {
	AVCaptureConnection *connection = self.output.connections.lastObject;
	if ([UIDevice currentDevice].orientation == UIDeviceOrientationPortrait)
		connection.videoOrientation = AVCaptureVideoOrientationPortrait;
	else if ([UIDevice currentDevice].orientation == UIDeviceOrientationPortraitUpsideDown)
		connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
	else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft)
		connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
	else if ([UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeRight)
		connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
	else { // fall back to statusbar orientation when the device is face up/down/unknown
		if ([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationPortrait)
			connection.videoOrientation = AVCaptureVideoOrientationPortrait;
		else if ([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationPortraitUpsideDown)
			connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
		else if ([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationLandscapeLeft)
			connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
		else if ([UIApplication sharedApplication].statusBarOrientation == UIDeviceOrientationLandscapeRight)
			connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
	}

	// should be the same as whats passed into setPreparedPhotoSettingsArray:completionHandler:, so either `AVCapturePhotoSettings.photoSettings` or `self.rawSettings`
	AVCapturePhotoSettings *settings = AVCapturePhotoSettings.photoSettings;
	[self.output capturePhotoWithSettings:settings delegate:self];
}

- (void) changeFocusPoint:(UITapGestureRecognizer *) doubleTapGestureRecognizer {
	[self.input.device lockForConfiguration:NULL];
	self.input.device.focusPointOfInterest = [doubleTapGestureRecognizer locationInView:doubleTapGestureRecognizer.view];
	self.input.device.exposurePointOfInterest = self.input.device.focusPointOfInterest;
	[self.input.device unlockForConfiguration];
}

#pragma mark -

- (void) flipTorchMode {
	[self.input.device lockForConfiguration:NULL];
	self.input.device.torchMode = (self.input.device.torchMode == AVCaptureTorchModeOff) ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
	[self.input.device unlockForConfiguration];
}

#pragma mark -

- (AVCapturePhotoSettings *) rawSettings {
	if (self.output.availableRawPhotoPixelFormatTypes.count == 0) {
		return nil;
	}

	return [AVCapturePhotoSettings photoSettingsWithRawPixelFormatType:self.output.availableRawPhotoPixelFormatTypes.firstObject.unsignedIntValue
													   processedFormat:@{ AVVideoCodecKey : AVVideoCodecTypeHEVC }];
}

#pragma mark -

- (void) captureOutput:(AVCapturePhotoOutput *) output willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *) resolvedSettings {
	[[UIDevice currentDevice] playInputClick];
}

- (void) captureOutput:(AVCapturePhotoOutput *) output didFinishProcessingPhoto:(AVCapturePhoto *) photo error:(nullable NSError *) error {
	NSLog(@"captured %@ with error? %@", photo, error);
	if (photo.isRawPhoto) {
		NSLog(@"Captured RAW photo");
	}
	CGImageRef cgImage = photo.CGImageRepresentation;
	if (cgImage) {
		UIImage *image = [UIImage imageWithCGImage:cgImage];
		UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
	}
}
@end
