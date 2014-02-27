//
//  CCHMapClusterControllerTests.m
//  CCHMapClusterController
//
//  Copyright (C) 2013 Claus Höfele
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "CCHMapClusterController.h"
#import "CCHMapClusterAnnotation.h"
#import "CCHFadeInOutMapAnimator.h"
#import "CCHMapClusterControllerUtils.h"

#import <XCTest/XCTest.h>

@interface CCHMapClusterControllerTests : XCTestCase

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) CCHMapClusterController *mapClusterController;
@property (nonatomic, assign) BOOL done;

@end

@implementation CCHMapClusterControllerTests

- (void)setUp
{
    [super setUp];

    self.mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    self.mapClusterController = [[CCHMapClusterController alloc] initWithMapView:self.mapView];
    self.done = NO;
}

- (BOOL)waitForCompletion:(NSTimeInterval)timeoutSecs
{
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    
    do {
        [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
        if (timeoutDate.timeIntervalSinceNow < 0.0) {
            break;
        }
    } while (!self.done);
    
    return self.done;
}

- (void)testAddAnnotationsNil
{
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:nil withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)0);
}

- (void)testAddAnnotationsSimple
{
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = CLLocationCoordinate2DMake(52.5, 13.5);
    MKCoordinateRegion region = MKCoordinateRegionMake(annotation.coordinate, MKCoordinateSpanMake(3, 3));
    self.mapView.region = region;
    
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:@[annotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)1);
}

- (void)testAddAnnotations
{
    // 3x3 grid
    self.mapView.frame = CGRectMake(0, 0, 300, 300);
    self.mapClusterController.marginFactor = 0;
    self.mapClusterController.cellSize = 100;

    // Grid spanning 51-54 lng, 12-15 lat
    MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(52.5, 13.5), MKCoordinateSpanMake(3, 3));
    MKMapRect visibleMapRect = CCHMapClusterControllerMapRectForCoordinateRegion(region);
    self.mapView.visibleMapRect = visibleMapRect;

    // Bottom left
    MKPointAnnotation *annotation0 = [[MKPointAnnotation alloc] init];
    annotation0.coordinate = CLLocationCoordinate2DMake(51.1, 12.1);
    
    // Top right
    MKPointAnnotation *annotation1 = [[MKPointAnnotation alloc] init];
    annotation1.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation2 = [[MKPointAnnotation alloc] init];
    annotation2.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation3 = [[MKPointAnnotation alloc] init];
    annotation3.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation4 = [[MKPointAnnotation alloc] init];
    annotation4.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation5 = [[MKPointAnnotation alloc] init];
    annotation5.coordinate = CLLocationCoordinate2DMake(53.9, 14.6);

    NSArray *annotations = @[annotation0, annotation1, annotation2, annotation3, annotation4, annotation5];
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:annotations withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapClusterController.annotations.count, (NSUInteger)6);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)2);

    // Origin MKCoordinateRegion -> bottom left, MKMapRect -> top left
    double cellWidth = visibleMapRect.size.width / 3;
    double cellHeight = visibleMapRect.size.height / 3;
    MKMapPoint cellOrigin = visibleMapRect.origin;

    // Check bottom left
    MKMapRect bottomLeftMapRect = MKMapRectMake(cellOrigin.x, cellOrigin.y + 2 * cellHeight, cellWidth, cellHeight);
    NSSet *annotationsInMapRect = [self.mapView annotationsInMapRect:bottomLeftMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)1);
    CCHMapClusterAnnotation *clusterAnnotation = (CCHMapClusterAnnotation *)annotationsInMapRect.anyObject;
    XCTAssertEqual(clusterAnnotation.annotations.count, (NSUInteger)1);

    // Check top right
    MKMapRect topRightMapRect = MKMapRectMake(cellOrigin.x + 2 * cellWidth, cellOrigin.y, cellWidth, cellHeight);
    annotationsInMapRect = [self.mapView annotationsInMapRect:topRightMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)1);
    clusterAnnotation = (CCHMapClusterAnnotation *)annotationsInMapRect.anyObject;
    XCTAssertEqual(clusterAnnotation.annotations.count, (NSUInteger)5);

    // Check center
    MKMapRect middleMapRect = MKMapRectMake(cellOrigin.x + cellWidth, cellOrigin.y + cellHeight, cellWidth, cellHeight);
    annotationsInMapRect = [self.mapView annotationsInMapRect:middleMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)0);
}

- (void)testRemoveAnnotations
{
    // 3x3 grid
    self.mapView.frame = CGRectMake(0, 0, 300, 300);
    self.mapClusterController.marginFactor = 0;
    self.mapClusterController.cellSize = 100;
    
    // Grid spanning 51-54 lng, 12-15 lat
    MKCoordinateRegion region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(52.5, 13.5), MKCoordinateSpanMake(3, 3));
    MKMapRect visibleMapRect = CCHMapClusterControllerMapRectForCoordinateRegion(region);
    self.mapView.visibleMapRect = visibleMapRect;
    
    // Bottom left
    MKPointAnnotation *annotation0 = [[MKPointAnnotation alloc] init];
    annotation0.coordinate = CLLocationCoordinate2DMake(51.1, 12.1);
    
    // Top right
    MKPointAnnotation *annotation1 = [[MKPointAnnotation alloc] init];
    annotation1.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation2 = [[MKPointAnnotation alloc] init];
    annotation2.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation3 = [[MKPointAnnotation alloc] init];
    annotation3.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation4 = [[MKPointAnnotation alloc] init];
    annotation4.coordinate = CLLocationCoordinate2DMake(53.9, 14.9);
    MKPointAnnotation *annotation5 = [[MKPointAnnotation alloc] init];
    annotation5.coordinate = CLLocationCoordinate2DMake(53.9, 14.6);
    
    NSArray *annotations = @[annotation0, annotation1, annotation2, annotation3, annotation4, annotation5];
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:annotations withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapClusterController.annotations.count, (NSUInteger)6);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)2);

    // Origin MKCoordinateRegion -> bottom left, MKMapRect -> top left
    double cellWidth = visibleMapRect.size.width / 3;
    double cellHeight = visibleMapRect.size.height / 3;
    MKMapPoint cellOrigin = visibleMapRect.origin;
    
    // Remove bottom left
    self.done = NO;
    [self.mapClusterController removeAnnotations:@[annotation0] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapClusterController.annotations.count, (NSUInteger)5);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)1);

    // Check bottom left
    MKMapRect bottomLeftMapRect = MKMapRectMake(cellOrigin.x, cellOrigin.y + 2 * cellHeight, cellWidth, cellHeight);
    NSSet *annotationsInMapRect = [self.mapView annotationsInMapRect:bottomLeftMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)0);
    
    // Check center
    MKMapRect middleMapRect = MKMapRectMake(cellOrigin.x + cellWidth, cellOrigin.y + cellHeight, cellWidth, cellHeight);
    annotationsInMapRect = [self.mapView annotationsInMapRect:middleMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)0);

    // Remove remaining annotations
    self.done = NO;
    [self.mapClusterController removeAnnotations:annotations withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)0);
    
    // Check visible region
    annotationsInMapRect = [self.mapView annotationsInMapRect:visibleMapRect];
    XCTAssertEqual(annotationsInMapRect.count, (NSUInteger)0);
}

- (void)testAddNonClusteredAnnotations
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(52.5, 13.5);

    MKPointAnnotation *nonClusteredAnnotation = [[MKPointAnnotation alloc] init];
    nonClusteredAnnotation.coordinate = coordinate;
    [self.mapView addAnnotation:nonClusteredAnnotation];

    MKPointAnnotation *clusteredAnnotation = [[MKPointAnnotation alloc] init];
    clusteredAnnotation.coordinate = coordinate;
    MKCoordinateRegion region = MKCoordinateRegionMake(clusteredAnnotation.coordinate, MKCoordinateSpanMake(3, 3));
    self.mapView.region = region;

    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:@[clusteredAnnotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);

    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)2);
    XCTAssertTrue([self.mapView.annotations containsObject:nonClusteredAnnotation]);

    NSMutableArray *annotations = [NSMutableArray arrayWithArray:self.mapView.annotations];
    [annotations removeObject:nonClusteredAnnotation];
    XCTAssertTrue([annotations.lastObject isKindOfClass:CCHMapClusterAnnotation.class]);
    CCHMapClusterAnnotation *clusterAnnotation = (CCHMapClusterAnnotation *)annotations.lastObject;
    XCTAssertTrue([clusterAnnotation.annotations containsObject:clusteredAnnotation]);
}

- (void)testAddAnnotationsWithDifferentControllers
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(52.5, 13.5);
    MKPointAnnotation *clusteredAnnotation = [[MKPointAnnotation alloc] init];
    clusteredAnnotation.coordinate = coordinate;
    
    MKCoordinateRegion region = MKCoordinateRegionMake(clusteredAnnotation.coordinate, MKCoordinateSpanMake(3, 3));
    self.mapView.region = region;
    
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:@[clusteredAnnotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);

    self.done = NO;
    CCHMapClusterController *mapClusterController2 = [[CCHMapClusterController alloc] initWithMapView:self.mapView];
    [mapClusterController2 addAnnotations:@[clusteredAnnotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    
    XCTAssertEqual(self.mapView.annotations.count, (NSUInteger)2);
    
    XCTAssertTrue([self.mapView.annotations[0] isKindOfClass:CCHMapClusterAnnotation.class]);
    XCTAssertTrue([[self.mapView.annotations[0] annotations] containsObject:clusteredAnnotation]);
    XCTAssertTrue([self.mapView.annotations[1] isKindOfClass:CCHMapClusterAnnotation.class]);
    XCTAssertTrue([[self.mapView.annotations[1] annotations] containsObject:clusteredAnnotation]);
}

#if TARGET_OS_IPHONE
- (void)testFadeInOut
{
    CCHFadeInOutMapAnimator *animator = [[CCHFadeInOutMapAnimator alloc] init];
    self.mapClusterController.animator = animator;
    
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = CLLocationCoordinate2DMake(52.5, 13.5);
    MKCoordinateRegion region = MKCoordinateRegionMake(annotation.coordinate, MKCoordinateSpanMake(3, 3));
    self.mapView.region = region;
    
    // Fade in
    __weak CCHMapClusterControllerTests *weakSelf = self;
    [self.mapClusterController addAnnotations:@[annotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    
    CCHMapClusterAnnotation *clusterAnnotation = [self.mapView.annotations lastObject];
    MKAnnotationView *annotationView = [self.mapView viewForAnnotation:clusterAnnotation];
    XCTAssertEqualWithAccuracy(annotationView.alpha, 1.0, __FLT_EPSILON__);
    
    // Fade Out
    self.done = NO;
    [self.mapClusterController removeAnnotations:@[annotation] withCompletionHandler:^{
        weakSelf.done = YES;
    }];
    XCTAssertTrue([self waitForCompletion:1.0]);
    XCTAssertEqualWithAccuracy(annotationView.alpha, 0.0, __FLT_EPSILON__);
}
#endif

@end
