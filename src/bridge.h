#import <Foundation/Foundation.h>

/// 安全地設定（可能是私有的）WebKit 偏好設定。
/// 若該 key 不存在會回傳 NO 而不是拋出 NSException 讓程式崩潰。
BOOL DynSetPreferenceSafe(id target, NSString *key, id value);
