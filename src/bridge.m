#import "bridge.h"

BOOL DynSetPreferenceSafe(id target, NSString *key, id value) {
    if (target == nil || key == nil) { return NO; }
    @try {
        [target setValue:value forKey:key];
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}
