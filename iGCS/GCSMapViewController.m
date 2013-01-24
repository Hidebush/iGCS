//
//  FirstViewController.m
//  iGCS
//
//  Created by Claudio Natoli on 5/02/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "GCSMapViewController.h"
#import <MapKit/MKUserLocation.h>

#import "MainViewController.h"
#import "WaypointAnnotation.h"
#import "GaugeViewCommon.h"

@implementation GCSMapViewController

@synthesize map;
@synthesize windIconView;
@synthesize ahIndicatorView;
@synthesize compassView;
@synthesize airspeedView;
@synthesize altitudeView;

@synthesize customModeLabel;
@synthesize baseModeLabel;
@synthesize statusLabel;

@synthesize gpsFixTypeLabel;
@synthesize numSatellitesLabel;

@synthesize sysUptimeLabel;
@synthesize sysVoltageLabel;
@synthesize sysMemFreeLabel;

@synthesize throttleLabel;
@synthesize climbRateLabel;
@synthesize groundSpeedLabel;
@synthesize windDirLabel;
@synthesize windSpeedLabel;
@synthesize windSpeedZLabel;
@synthesize voltageLabel;
@synthesize currentLabel;

@synthesize autoButton;

#define AIRPLANE_ICON_SIZE 48

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
    
    // Release any cached data, images, etc that aren't in use.
#if DO_NSLOG
    if ([self isViewLoaded]) {
        NSLog(@"\t\tGCSMapViewController::didReceiveMemoryWarning: view is still loaded");
    } else {
        NSLog(@"\t\tGCSMapViewController::didReceiveMemoryWarning: view is NOT loaded");
    }
#endif
}

- (void)awakeFromNib {
    uavPos  = [[MKPointAnnotation alloc] init];
    [uavPos setCoordinate:CLLocationCoordinate2DMake(0, 0)];

    uavView = [[MKAnnotationView  alloc] initWithAnnotation:uavPos reuseIdentifier:@"uavView"];
    uavView.image = [GCSMapViewController imageWithImage: [UIImage imageNamed:@"airplane.png"] 
                                                scaledToSize:CGSizeMake(AIRPLANE_ICON_SIZE,AIRPLANE_ICON_SIZE)
                                                rotation: 0];
    uavView.centerOffset = CGPointMake(0, 0);
    
    gotoPos = nil;
    gotoAltitude = 50;
    
    trackMKMapPointsLen = 1000;
    trackMKMapPoints = malloc(trackMKMapPointsLen * sizeof(MKMapPoint));
    numTrackPoints = 0;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

	// Do any additional setup after loading the view, typically from a nib.
    map.delegate = self;
    [map addAnnotation:uavPos];
    
    // Add recognizer for long holds => GOTO point
    UILongPressGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] 
                                                      initWithTarget:self action:@selector(handleLongPressGesture:)];
    longPressGesture.numberOfTapsRequired = 0;
    longPressGesture.numberOfTouchesRequired = 1;
    longPressGesture.minimumPressDuration = 1.0;
    [map addGestureRecognizer:longPressGesture];
    
    // Initialize subviews
    [ahIndicatorView setRoll: 0 pitch: 0];
    [compassView setHeading: 0];
    
    [airspeedView setScale:10];
    [airspeedView setValue:0];
    
    [altitudeView setScale:100];
    [altitudeView setValue:0];
    
    windIconView = [[UIImageView alloc] initWithImage:[GCSMapViewController image:[UIImage imageNamed:@"193-location-arrow.png"]
                                                                        withColor:[UIColor redColor]]];
    windIconView.frame = CGRectMake(10, 10, windIconView.frame.size.width, windIconView.frame.size.height);
    [map addSubview: windIconView];
    windIconView.transform = CGAffineTransformMakeRotation((WIND_ICON_OFFSET_ANG) * M_PI/180.0f);
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (IBAction) readWaypointButtonClick {
    [(MainViewController*)[self parentViewController] issueReadWaypointsRequest];
}

- (IBAction) autoButtonClick {
    [(MainViewController*)[self parentViewController] issueSetAUTOModeCommand];
}

- (void)alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([[actionSheet buttonTitleAtIndex:buttonIndex] isEqualToString:@"OK"]) {
        // Drop an icon for the proposed GOTO point
        if (gotoPos != nil)
            [map removeAnnotation:gotoPos];

        gotoPos = [[GotoPointAnnotation alloc] initWithCoordinate:gotoCoordinates];
        [map addAnnotation:gotoPos];
        [map setNeedsDisplay];
        
        // Let's go!
        [(MainViewController*)[self parentViewController] issueGOTOCommand: gotoCoordinates withAltitude:gotoAltitude];
    }
}

-(void)handleLongPressGesture:(UIGestureRecognizer*)sender {
    if (sender.state != UIGestureRecognizerStateBegan)
        return;

    // Set the coordinates of the map point being held down
    gotoCoordinates = [map convertPoint:[sender locationInView:map] toCoordinateFromView:map];
    
    // Confirm acceptance of GOTO point
    UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Set GOTO position"
                                                      message:[NSString stringWithFormat:@"%0.5f,%0.5f %0.1fm",
                                                                gotoCoordinates.longitude, gotoCoordinates.latitude, gotoAltitude]
                                                     delegate:self
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:@"Cancel", nil];
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc]
                                          initWithTarget:self action:@selector(handlePanGesture:)];
    panGesture.minimumNumberOfTouches = 1;
    panGesture.maximumNumberOfTouches = 1;
    //[message setMultipleTouchEnabled:YES];
    //[message setUserInteractionEnabled:YES];
    [message addGestureRecognizer:panGesture];

    [message show];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)sender {
    CGPoint translate = [sender translationInView:self.view];

    static CGPoint lastTranslate;
    if (sender.state == UIGestureRecognizerStateBegan) {
        lastTranslate = translate;
        return;
    }
    
    gotoAltitude += (lastTranslate.y-translate.y)/10;
    lastTranslate = translate;
    
    UIAlertView *view = (UIAlertView*)(sender.view);
    [view setMessage:[NSString stringWithFormat:@"%0.5f,%0.5f %0.1fm",
                      gotoCoordinates.longitude, gotoCoordinates.latitude, gotoAltitude]];    
}

- (void) removeExistingWaypointAnnotations {
    [map removeAnnotations:
        [map.annotations
            filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"(self isKindOfClass: %@)",
                                         [WaypointAnnotation class]]]];
}

- (WaypointAnnotation *) getWaypointAnnotation:(int)waypointSeq {
    for (unsigned int i =0; i < [map.annotations count]; i++) {
        id annotation = [map.annotations objectAtIndex:i];
        if ([annotation isKindOfClass:[WaypointAnnotation class]]) {
            WaypointAnnotation *waypointAnnotation = (WaypointAnnotation*)annotation;
            if ([waypointAnnotation isCurrentWaypointP:waypointSeq]) {
                return waypointAnnotation;
            }
        }
    }
    return nil;
}

- (void) updateWaypoints:(WaypointsHolder *)_waypoints {

    // Clean up existing objects
    [self removeExistingWaypointAnnotations];
    [map removeOverlay:waypointRoutePolyline];

    // Get the nav-specfic waypoints
    WaypointsHolder *navWaypoints = [_waypoints getNavWaypoints];
    unsigned int numWaypoints = [navWaypoints numWaypoints];

    MKMapPoint *navMKMapPoints = malloc(sizeof(MKMapPoint) * numWaypoints);
    
    // Add waypoint annotations, and convert to array of MKMapPoints
    for (unsigned int i = 0; i < numWaypoints; i++) {
        mavlink_mission_item_t waypoint = [navWaypoints getWaypoint:i];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(waypoint.x, waypoint.y);
        
        // Add the annotation
        WaypointAnnotation *annotation = [[WaypointAnnotation alloc] initWithCoordinate:coordinate andWayPoint:waypoint];
        [map addAnnotation:annotation];
        
        // Construct the MKMapPoint
        navMKMapPoints[i] = MKMapPointForCoordinate(coordinate);
    }
        
    // Add the polyline overlay
    waypointRoutePolyline = [MKPolyline polylineWithPoints:navMKMapPoints count:numWaypoints];
    [map addOverlay:waypointRoutePolyline];
    
    // Set the map extents
    [map setVisibleMapRect:[waypointRoutePolyline boundingMapRect]];
    
    [map setNeedsDisplay];
    
    free(navMKMapPoints);
}

// FIXME: consider more efficient (and safe?) ways to do this - see iOS Breadcrumbs sample code
- (void) updateTrack:(CLLocationCoordinate2D)pos {
    MKMapPoint newPoint = MKMapPointForCoordinate(pos);
    
    // Check distance from 0
    if (MKMetersBetweenMapPoints(newPoint, MKMapPointForCoordinate(CLLocationCoordinate2DMake(0, 0))) < 1.0) {
        return;
    }

    // Check distance from last point
    if (numTrackPoints > 0) {
        if (MKMetersBetweenMapPoints(newPoint, trackMKMapPoints[numTrackPoints-1]) < 1.0) {
            return;
        }
    }

    // Check array bounds
    if (numTrackPoints == trackMKMapPointsLen) {
        MKMapPoint *newAlloc = realloc(trackMKMapPoints, trackMKMapPointsLen*2 * sizeof(MKMapPoint));
        if (newAlloc == nil)
            return;
        trackMKMapPoints = newAlloc;
        trackMKMapPointsLen *= 2;
    }
    
    // Add the next coord
    trackMKMapPoints[numTrackPoints] = newPoint;
    numTrackPoints++;
    
    // Clean up existing objects
    [map removeOverlay:trackPolyline];

    trackPolyline = [MKPolyline polylineWithPoints:trackMKMapPoints count:numTrackPoints];
    
    // Add the polyline overlay
    [map addOverlay:trackPolyline];
    [map setNeedsDisplay];
}

// FIXME: move the below utilities to some "utils" file
+ (NSString*) mavModeEnumToString:(enum MAV_MODE)mode {
    NSString *str = [NSString stringWithFormat:@""];
    if (mode & MAV_MODE_FLAG_TEST_ENABLED)          str = [str stringByAppendingString:@"Test "];
    if (mode & MAV_MODE_FLAG_AUTO_ENABLED)          str = [str stringByAppendingString:@"Auto "];
    if (mode & MAV_MODE_FLAG_GUIDED_ENABLED)        str = [str stringByAppendingString:@"Guided "];
    if (mode & MAV_MODE_FLAG_STABILIZE_ENABLED)     str = [str stringByAppendingString:@"Stabilize "];
    if (mode & MAV_MODE_FLAG_HIL_ENABLED)           str = [str stringByAppendingString:@"HIL "];
    if (mode & MAV_MODE_FLAG_MANUAL_INPUT_ENABLED)  str = [str stringByAppendingString:@"Manual "];
    if (mode & MAV_MODE_FLAG_CUSTOM_MODE_ENABLED)   str = [str stringByAppendingString:@"Custom "];
    if (!(mode & MAV_MODE_FLAG_SAFETY_ARMED))       str = [str stringByAppendingString:@"(Disarmed)"];
    return str;
}

+ (NSString*) mavStateEnumToString:(enum MAV_STATE)state {
    switch (state) {
        case MAV_STATE_UNINIT:      return @"Uninitialized";
        case MAV_STATE_BOOT:        return @"Boot";
        case MAV_STATE_CALIBRATING: return @"Calibrating";
        case MAV_STATE_STANDBY:     return @"Standby";
        case MAV_STATE_ACTIVE:      return @"Active";
        case MAV_STATE_CRITICAL:    return @"Critical";
        case MAV_STATE_EMERGENCY:   return @"Emergency";
        case MAV_STATE_POWEROFF:    return @"Power Off";
        case MAV_STATE_ENUM_END:    break;
    }
    return [NSString stringWithFormat:@"MAV_STATE (%d)", state];
}

+ (NSString*) mavCustomModeToString:(int)customMode {
    switch (customMode) {
        case MANUAL:        return @"Manual";
        case CIRCLE:        return @"Circle";
        case STABILIZE:     return @"Stabilize";
        case FLY_BY_WIRE_A: return @"FBW_A";
        case FLY_BY_WIRE_B: return @"FBW_B";
        case FLY_BY_WIRE_C: return @"FBW_C";
        case AUTO:          return @"Auto";
        case RTL:           return @"RTL";
        case LOITER:        return @"Loiter";
        case TAKEOFF:       return @"Takeoff";
        case LAND:          return @"Land";
        case GUIDED:        return @"Guided";
        case INITIALISING:  return @"Initialising";

    }
    return [NSString stringWithFormat:@"CUSTOM_MODE (%d)", customMode];
}

- (void) handlePacket:(mavlink_message_t*)msg {
    
    // FIXME: try to avoid repeated work here 
    // (i.e. if yaw hasn't changed, or position hasn't discernibly 
    // changed relative to view, don't update)
    switch (msg->msgid) {
        /*
        // Temporarily disabled in favour of MAVLINK_MSG_ID_GPS_RAW_INT
        case MAVLINK_MSG_ID_GLOBAL_POSITION_INT:
        {
            mavlink_global_position_int_t gpsPosIntPkt;
            mavlink_msg_global_position_int_decode(msg, &gpsPosIntPkt);
            
            CLLocationCoordinate2D pos = CLLocationCoordinate2DMake(gpsPosIntPkt.lat/10000000.0, gpsPosIntPkt.lon/10000000.0);
            [uavPos setCoordinate:pos];
            [self updateTrack:pos];
        }
        break;
        */
        case MAVLINK_MSG_ID_GPS_RAW_INT:
        {
            mavlink_gps_raw_int_t gpsRawIntPkt;
            mavlink_msg_gps_raw_int_decode(msg, &gpsRawIntPkt);
            
            CLLocationCoordinate2D pos = CLLocationCoordinate2DMake(gpsRawIntPkt.lat/10000000.0, gpsRawIntPkt.lon/10000000.0);
            [uavPos setCoordinate:pos];
            [self updateTrack:pos];
            
            [numSatellitesLabel setText:[NSString stringWithFormat:@"%d", gpsRawIntPkt.satellites_visible]];
            [gpsFixTypeLabel    setText: (gpsRawIntPkt.fix_type == 3) ? @"3D" :
                                        ((gpsRawIntPkt.fix_type == 2) ? @"2D" : @"No fix")];
        }
        break;
            
        case MAVLINK_MSG_ID_GPS_STATUS:
        {
            mavlink_gps_status_t gpsStatus;
            mavlink_msg_gps_status_decode(msg, &gpsStatus);
            [numSatellitesLabel setText:[NSString stringWithFormat:@"%d", gpsStatus.satellites_visible]];
        }
        break;
            
        case MAVLINK_MSG_ID_ATTITUDE:
        {
            mavlink_attitude_t attitudePkt;
            mavlink_msg_attitude_decode(msg, &attitudePkt);
            
            uavView.image = [GCSMapViewController imageWithImage: [UIImage imageNamed:@"airplane.png"] 
                                                    scaledToSize:CGSizeMake(AIRPLANE_ICON_SIZE,AIRPLANE_ICON_SIZE)
                                                        rotation: attitudePkt.yaw];
            
            [ahIndicatorView setRoll:-attitudePkt.roll pitch:attitudePkt.pitch];
            [ahIndicatorView requestRedraw];
            
            [sysUptimeLabel  setText:[NSString stringWithFormat:@"%0.1f s", attitudePkt.time_boot_ms/1000.0f]];
        }
        break;

        case MAVLINK_MSG_ID_VFR_HUD:
        {
            mavlink_vfr_hud_t  vfrHudPkt;
            mavlink_msg_vfr_hud_decode(msg, &vfrHudPkt);
            
            [compassView setHeading:vfrHudPkt.heading];
            [airspeedView setValue:vfrHudPkt.airspeed]; // m/s
            [altitudeView setValue:vfrHudPkt.alt];      // m

            [compassView  requestRedraw];
            [airspeedView requestRedraw];
            [altitudeView requestRedraw];
            
            [throttleLabel    setText:[NSString stringWithFormat:@"%d%%", vfrHudPkt.throttle]];
            [climbRateLabel   setText:[NSString stringWithFormat:@"%0.1f m/s", vfrHudPkt.climb]];
            [groundSpeedLabel setText:[NSString stringWithFormat:@"%0.1f m/s", vfrHudPkt.groundspeed]];
        }
        break;
            
        case MAVLINK_MSG_ID_NAV_CONTROLLER_OUTPUT:
        {
            mavlink_nav_controller_output_t navCtrlOutPkt;
            mavlink_msg_nav_controller_output_decode(msg, &navCtrlOutPkt);
            
            [compassView setNavBearing:navCtrlOutPkt.nav_bearing];
            [airspeedView setTargetDelta:navCtrlOutPkt.aspd_error]; // m/s
            [altitudeView setTargetDelta:navCtrlOutPkt.alt_error];  // m
        }
        break;
            
        case MAVLINK_MSG_ID_MISSION_CURRENT:
        {
            mavlink_mission_current_t currentWaypoint;
            mavlink_msg_mission_current_decode(msg, &currentWaypoint);

            // We've seen a new waypoint, so...
            if (currentWaypointNum != currentWaypoint.seq) {
    
                // Reset the associated annotations
                for (int i = 0; i < 2; i++) {
                    WaypointAnnotation *annotation = [self getWaypointAnnotation:currentWaypointNum];
                    
                    // Update the current value (on the first iteration, we want this after the
                    // getWaypointAnnotation call, but before the addAnnotation)
                    currentWaypointNum = currentWaypoint.seq;

                    if (annotation) {
                        [map removeAnnotation:annotation];
                        [map addAnnotation:annotation];
                    }
                }
            }
        }
        break;
            
        case MAVLINK_MSG_ID_SYS_STATUS:
        {
            mavlink_sys_status_t sysStatus;
            mavlink_msg_sys_status_decode(msg, &sysStatus);
            [voltageLabel setText:[NSString stringWithFormat:@"%0.1fV", sysStatus.voltage_battery/1000.0f]];
            [currentLabel setText:[NSString stringWithFormat:@"%0.1fA", sysStatus.current_battery/100.0f]];
        }
        break;

        case MAVLINK_MSG_ID_WIND:
        {
            mavlink_wind_t wind;
            mavlink_msg_wind_decode(msg, &wind);
            [windDirLabel    setText:[NSString stringWithFormat:@"%d", (int)wind.direction]];
            [windSpeedLabel  setText:[NSString stringWithFormat:@"%0.1f m/s", wind.speed]];
            [windSpeedZLabel setText:[NSString stringWithFormat:@"%0.1f m/s", wind.speed_z]];
            
            windIconView.transform = CGAffineTransformMakeRotation(((360 + (int)wind.direction + WIND_ICON_OFFSET_ANG) % 360) * M_PI/180.0f);
        }
        break;
            
        case MAVLINK_MSG_ID_HWSTATUS:
        {
            mavlink_hwstatus_t hwStatus;
            mavlink_msg_hwstatus_decode(msg, &hwStatus);
            [sysVoltageLabel setText:[NSString stringWithFormat:@"%0.2fV", hwStatus.Vcc/1000.f]];
        }
        break;
            
        case MAVLINK_MSG_ID_MEMINFO:
        {
            mavlink_meminfo_t memFree;
            mavlink_msg_meminfo_decode(msg, &memFree);
            [sysMemFreeLabel setText:[NSString stringWithFormat:@"%0.1fkB", memFree.freemem/1024.0f]];
        }
        break;
            
        case MAVLINK_MSG_ID_HEARTBEAT:
        {
            mavlink_heartbeat_t heartbeat;
            mavlink_msg_heartbeat_decode(msg, &heartbeat);
            
            [customModeLabel    setText:[GCSMapViewController mavCustomModeToString:  heartbeat.custom_mode]];
            [baseModeLabel      setText:[GCSMapViewController mavModeEnumToString:    heartbeat.base_mode]];
            [statusLabel        setText:[GCSMapViewController mavStateEnumToString:   heartbeat.system_status]];
                        
            // Dis/enable the AUTO button
            if ((heartbeat.custom_mode == AUTO) == autoButton.isEnabled) {
                autoButton.enabled = !autoButton.isEnabled;
            }
        }
        break;
    }
}

+ (UIImage*)imageWithImage:(UIImage*)image scaledToSize:(CGSize)newSize rotation:(double)ang
{
    UIGraphicsBeginImageContext( newSize );
    //[image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    
    CGContextRef context = UIGraphicsGetCurrentContext();   
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, newSize.width/2, newSize.height/2);
    transform = CGAffineTransformRotate(transform, ang);
    CGContextConcatCTM(context, transform);
    
    [image drawInRect:CGRectMake(-newSize.width/2,-newSize.width/2,newSize.width,newSize.height)];

    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

// FIXME: move to some "utils" file
// ref: http://coffeeshopped.com/2010/09/iphone-how-to-dynamically-color-a-uiimage
+ (UIImage *)image:(UIImage*)img withColor:(UIColor*)color {
    
    
    // begin a new image context, to draw our colored image onto
    UIGraphicsBeginImageContext(img.size);
    
    // get a reference to that context we created
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // translate/flip the graphics context (for transforming from CG* coords to UI* coords
    CGContextTranslateCTM(context, 0, img.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGRect rect = CGRectMake(0, 0, img.size.width, img.size.height);
    CGContextDrawImage(context, rect, img.CGImage);
    
    // Set a mask that matches the shape of the image, then draw as black
    [[UIColor blackColor] setFill];
    CGContextSetBlendMode(context, kCGBlendModeDarken);
    CGContextClipToMask(context, rect, img.CGImage);
    CGContextAddRect(context, rect);
    CGContextDrawPath(context,kCGPathFill);

    // Now replace with the desired color
    [color setFill];
    CGContextSetBlendMode(context, kCGBlendModeLighten);
    CGContextClipToMask(context, rect, img.CGImage);
    CGContextAddRect(context, rect);
    CGContextDrawPath(context,kCGPathFill);
    
    // generate a new UIImage from the graphics context we drew onto
    UIImage *coloredImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
     
    //return the color-burned image
    return coloredImg;  
}

- (MKAnnotationView *)mapView:(MKMapView *)theMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    // If it's the user location, just return nil.
    if ([annotation isKindOfClass:[MKUserLocation class]])
        return nil;
    
    // Handle our custom annotations
    //
    if ([annotation isKindOfClass:[WaypointAnnotation class]]) {
        
        NSString* identifier = @"WAYPOINT";
        MKAnnotationView *view = (MKAnnotationView*) [map dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (view == nil) {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
        } else {
            view.annotation = annotation;
        }
        
        WaypointAnnotation *waypointAnnotation = (WaypointAnnotation*)annotation;
        
        view.enabled = YES;
        view.canShowCallout = YES;
        
        // FIXME: memoize view.image generation
        if ([waypointAnnotation isCurrentWaypointP:currentWaypointNum]) {
            view.centerOffset = CGPointMake(0,0);      
            view.image = [GCSMapViewController image:[UIImage imageNamed:@"13-target.png"] 
                                           withColor:WAYPOINT_NAV_NEXT_COLOR];
        } else {
            view.centerOffset = CGPointMake(0,-12); // adjust for offset pointer in map marker        
            view.image = [GCSMapViewController image:[UIImage imageNamed:@"07-map-marker.png"] 
                                           withColor:[waypointAnnotation getColor]]; 
        }
        return view;
    }
    
    if ([annotation isKindOfClass:[GotoPointAnnotation class]]) {
        NSString* identifier = @"GOTOPOINT";
        MKAnnotationView *view = (MKAnnotationView*) [map dequeueReusableAnnotationViewWithIdentifier:identifier];
        if (view == nil) {
            view = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:identifier];
        } else {
            view.annotation = annotation;
        }
        
        view.enabled = YES;
        view.canShowCallout = YES;
        view.centerOffset = CGPointMake(0,0);      
        view.image = [GCSMapViewController image:[UIImage imageNamed:@"13-target.png"] 
                                        withColor:WAYPOINT_LINE_COLOR];
        return view;
    }
    
    if ([annotation isKindOfClass:[MKPointAnnotation class]]) {
        return uavView;
    }
    
    return nil;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id)overlay
{
    if (overlay == waypointRoutePolyline) {
        waypointRouteView = [[MKPolylineView alloc] initWithPolyline:overlay];
        waypointRouteView.fillColor     = WAYPOINT_LINE_COLOR;
        waypointRouteView.strokeColor   = WAYPOINT_LINE_COLOR;
        waypointRouteView.lineWidth     = 3;
        return waypointRouteView;
    } else if (overlay == trackPolyline) {
        trackView = [[MKPolylineView alloc] initWithPolyline:overlay];
        trackView.fillColor     = TRACK_LINE_COLOR;
        trackView.strokeColor   = TRACK_LINE_COLOR;
        trackView.lineWidth     = 2;
        return trackView;
    }
    
    return nil;
}

@end
