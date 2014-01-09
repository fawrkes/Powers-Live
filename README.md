Powers-Live
===========

DESCRIPTION:

The Powers Live mobile application connects audiences in venues around the world, viewing a satellite broadcast of Tod Machover's opera, "Death and the Powers," to the live performance presented in Dallas, Texas on February 16, 2014. Using the app during the performance, you will experience visual and sonic aspects of the production extending off of the projection screen onto your iOS device. Video, audio, and live graphical content is triggered in the application in sync with the live performance and your interaction with this app influences the live production in Dallas, including interactive lighting on the Winspear Opera House's Moody Foundation Chandelier and a "Memory Upload" sequence, which incorporates your Facebook photos into your unique mobile experience. To learn more about the event, visit http://email.kultureshock.net/t/r-B7A0F2E658E7063A2540EF23F30FEDED

=========================================================================================================

TESTING PROCEDURE:

1. Run app
2. Select "Other" in the Location Box, and tap "Submit / Continue"
3. Optionally log in with a Facebook account or tap "Skip" 
4. App will download updated media if available.
5. You will reach a screen that says "Congratulations! You've completed setting up..."
6. To Test production content, navigate to the following administrative interface http://nicholas.media.mit.edu/admin/v4/ 

This interface is only used by production personnel to manually monitor and trigger app events. During the live performance, events are triggered directly by musicians on stage. 

7. Trigger the following example cues by typing the numbers below in the "Trigger Cue" field and clicking the "Trigger" button. 

303 - Looping video of cans; 
338 - Robot displayed after short pause, robot response to touch;
440 - Video of man yawning;
449 - Interactive matrix of particles;
577 - Introspective video of man with tree, accompanied by device vibration;
661 - White drips, touch and drag up or down to create your own drips;
669 - Blue mist, drag to perturb;

ADDITIONAL INFORMATION:

This iOS application, "Powers Live," is designed to accompany the live simulcast of the opera Death and the Powers (http://powers.media.mit.edu) to be performed on 16 February 2014 in Dallas, Texas. The application presents simulcast audiences in venues around the world with interactive visual and sonic content that parallels the visual design of the stage production. The content includes generative visuals rendered in a web view using HTML5 canvas and JavaScript, as well as pre-rendered video and audio that are displayed natively by the application. This allows the content to be initiated, played, and modified in synchrony with the satellite video broadcast that audience members with mobile devices in remote venues will be viewing.

Upon download and running the application for the first time, the application guides users through a few simple set-up steps. These include requesting the venue where the user will be attending the opera's simulcast, and an optional Facebook login. The application will proceed to download any additional updates to the audio, video, and image content that comes pre-cached within the application. If the app is run prior to the event, the user experience will conclude with a statement reminding the user to return to the app during the 16 February simulcast. On subsequent invocations of the application, it will check for content updates and download them if network connectivity is available. The requests for set-up information are not presented if the user has previously completed these steps. 

At each simulcast performance venue, users will be instructed to connect to a particular Wi-Fi network deployed in the simulcast venues for this experience. Once the performance begins, users will be presented with production content rendered in the web view. The application and web view will initiate WebSocket connections to servers located at the MIT Media Lab, which will aggregate data from connected clients and relay the cue triggers from the Dallas performance. WebSocket messages are acknowledged by the application and web view for monitoring at the MIT Media Lab and Dallas (Winspear Opera House) locations. Live performance data captured from performers and audio, generally a single floating point value, are also relayed to the mobile application web view in order to influence the generative graphics in a responsive manner. Many of the visual cues in the web view respond to touch input and some respond to touch input and or device motion and transmit this data back to the servers. The servers will aggregate user input from multiple devices and relay the aggregate value to the Dallas performance where the data will be used to influence visuals and LED lighting onstage and in the opera house.