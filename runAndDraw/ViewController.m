//
//  ViewController.m
//  runAndDraw
//
//  Created by shaobin on 2018/5/8.
//  Copyright © 2018年 autonavi. All rights reserved.
//

#import "ViewController.h"
#import <MAMapKit/MAMapKit.h>

@interface ViewController ()<MAMapViewDelegate> {
    CLLocationCoordinate2D *_coordBuffer;
    NSInteger _coordBufferCapacity;
    
    CLLocationCoordinate2D *_points;
    NSInteger _pointCount;
    CGFloat _duration;
}

@property (nonatomic, strong) MAMapView *mapView;

@property (nonatomic, strong) MAAnimatedAnnotation *movingCar;

@property (nonatomic, strong) MAPolyline *polyline;

@end

@implementation ViewController

#pragma mark - Map Delegate
- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if (annotation == self.movingCar) {
        NSString *pointReuseIndetifier = @"pointReuseIndetifier1";
        
        MAAnnotationView *annotationView = (MAAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pointReuseIndetifier];
        if(!annotationView) {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:pointReuseIndetifier];
            annotationView.canShowCallout = NO;
            
            UIImage *imge  =  [UIImage imageNamed:@"car1"];
            annotationView.image =  imge;
        }
        
        return annotationView;
    }
    
    return nil;
}

- (MAPolylineRenderer *)mapView:(MAMapView *)mapView rendererForOverlay:(id<MAOverlay>)overlay {
    if(overlay == self.polyline) {
        MAPolylineRenderer *polylineView = [[MAPolylineRenderer alloc] initWithPolyline:overlay];
        
        polylineView.lineWidth   = 8.f;
        polylineView.strokeColor = [UIColor purpleColor];
        
        return polylineView;
    }
    
    return nil;
}

#pragma mark life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //init buffer
    if(!_coordBuffer) {
        _coordBufferCapacity = 100000;
        _coordBuffer = malloc(_coordBufferCapacity * sizeof(CLLocationCoordinate2D));
    }
    
    [self initPoints];
    
    self.mapView = [[MAMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.zoomLevel = 12;
    self.mapView.cameraDegree = 80;
    self.mapView.delegate = self;
    
    self.movingCar = [[MAAnimatedAnnotation alloc] init];
    self.movingCar.coordinate = _points[0];
    [self.mapView addAnnotation:self.movingCar];
    self.mapView.mapType = MAMapTypeSatellite;
    
    [self.mapView showAnnotations:@[self.movingCar] animated:YES];
    
    [self.view addSubview:self.mapView];
    
    [self initBtn];
}

- (void)dealloc {
    if(_coordBuffer != NULL) {
        free(_coordBuffer);
        _coordBuffer = NULL;
    }
}

- (void)initPoints {
    NSString *mainBunldePath = [[NSBundle mainBundle] bundlePath];
    NSString *fileFullPath = [NSString stringWithFormat:@"%@/%@",mainBunldePath,@"points.txt"];
    if(![[NSFileManager defaultManager] fileExistsAtPath:fileFullPath]) {
        return;
    }
    
    NSData *data = [NSData dataWithContentsOfFile:fileFullPath];
    NSError *err = nil;
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray *arr = [str componentsSeparatedByString:@","];
    if(!arr) {
        NSLog(@"[AMap]: %@", err);
        return;
    }
    
    _pointCount = MIN(arr.count / 2, 1000);
    _points = malloc(sizeof(CLLocationCoordinate2D) * _pointCount);
    for(int i = 0; i < _pointCount; ++i) {
        NSString *lon = arr[2*i];
        NSString *lat = arr[2*i + 1];
        _points[i] = CLLocationCoordinate2DMake([lat doubleValue], [lon doubleValue]);
    }
    
    CGFloat sum = 0;
    for(int i = 1; i < _pointCount; ++i) {
        sum += MAMetersBetweenMapPoints(MAMapPointForCoordinate(_points[i-1]), MAMapPointForCoordinate(_points[i]));
    }
    _duration = sum / (120 * 3.6);
}

- (void)resizeCoordBuffer {
    if(_coordBuffer != NULL) {
        free(_coordBuffer);
        _coordBuffer = NULL;
    }
    
    if(_coordBufferCapacity == 0) {
        _coordBufferCapacity = 100000;
    } else {
        _coordBufferCapacity *= 2;
    }
    _coordBuffer = malloc(_coordBufferCapacity * sizeof(CLLocationCoordinate2D));
}

- (void)initBtn {
    UIButton * btn = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btn.frame = CGRectMake(0, 100, 60, 40);
    btn.backgroundColor = [UIColor grayColor];
    [btn setTitle:@"move" forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(mov) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btn];
    
    UIButton * btn1 = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    btn1.frame = CGRectMake(0, 200, 60, 40);
    btn1.backgroundColor = [UIColor grayColor];
    [btn1 setTitle:@"stop" forState:UIControlStateNormal];
    [btn1 addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:btn1];
}

#pragma mark - Action

- (void)mov {
    __weak typeof(self) weakSelf = self;
    [self.movingCar addMoveAnimationWithKeyCoordinates:_points count:_pointCount withDuration:_duration withName:nil completeCallback:^(BOOL isFinished) {
        ;
    } stepCallback:^(MAAnnotationMoveAnimation *currentAni) {
        [weakSelf updatePolylineWith:currentAni];
    } ];
}

- (void)stop {
    for(MAAnnotationMoveAnimation *ani in self.movingCar.allMoveAnimations) {
        [ani cancel];
    }
    
    self.movingCar.coordinate = _points[0];
}

- (void)updatePolylineWith:(MAAnnotationMoveAnimation*)ani {
    NSInteger count = ani.passedPointCount + 1;
    while(ani.passedPointCount + 1 > _coordBufferCapacity) {
        [self resizeCoordBuffer];
    }
    
    memcpy(_coordBuffer, ani.coordinates, sizeof(CLLocationCoordinate2D) * ani.passedPointCount);
    _coordBuffer[ani.passedPointCount] = self.movingCar.coordinate;
    
    if(!self.polyline) {
        self.polyline = [MAPolyline polylineWithCoordinates:_coordBuffer count:count];
        [self.mapView addOverlay:self.polyline];
    } else {
        [self.polyline setPolylineWithCoordinates:_coordBuffer count:count];
    }
    
    MAMapStatus *status = [self.mapView getMapStatus];
    status.rotationDegree += 0.1;
    status.centerCoordinate = self.movingCar.coordinate;
    [self.mapView setMapStatus:status animated:NO];
}

@end

