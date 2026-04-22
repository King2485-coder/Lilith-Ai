#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "atom_neutral" asset catalog image resource.
static NSString * const ACImageNameAtomNeutral AC_SWIFT_PRIVATE = @"atom_neutral";

/// The "atom_smirk" asset catalog image resource.
static NSString * const ACImageNameAtomSmirk AC_SWIFT_PRIVATE = @"atom_smirk";

/// The "atom_thinking" asset catalog image resource.
static NSString * const ACImageNameAtomThinking AC_SWIFT_PRIVATE = @"atom_thinking";

#undef AC_SWIFT_PRIVATE
