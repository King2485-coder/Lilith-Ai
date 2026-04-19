import Foundation

enum ThreadPresence: String, Codable, Hashable, CaseIterable {
    case online
    case offline
    case away
}

enum LilithCallType: String, Codable, Hashable, CaseIterable {
    case voice
    case video
}

enum LilithCallState: String, Codable, Hashable {
    case ringing
    case active
    case ended
}

enum LilithPostAudience: String, Codable, Hashable, CaseIterable {
    case publicFeed
    case followers
    case closeFriends
}

enum LilithProfileVisibility: String, Codable, Hashable {
    case publicProfile
    case privateProfile
}

struct LilithUser: Codable, Hashable, Identifiable {
    let id: String
    let name: String
    let handle: String
    let avatarURL: String?
}

struct LilithIdentityProfile: Codable, Hashable {
    var id: String
    var username: String
    let displayName: String
    let handle: String
    let bio: String
    var recoveryEmail: String?
    var phoneNumber: String?
    var location: String?
    var visibility: LilithProfileVisibility
    var followerCount: Int
    var followingCount: Int
    var connectionCount: Int
    var avatarSeed: Int
    let profileImageURL: String?

    init(
        id: String,
        username: String,
        displayName: String,
        bio: String,
        recoveryEmail: String?,
        phoneNumber: String?,
        location: String?,
        visibility: LilithProfileVisibility,
        followerCount: Int,
        followingCount: Int,
        connectionCount: Int,
        avatarSeed: Int,
        profileImageURL: String? = nil
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.handle = username
        self.bio = bio
        self.recoveryEmail = recoveryEmail
        self.phoneNumber = phoneNumber
        self.location = location
        self.visibility = visibility
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.connectionCount = connectionCount
        self.avatarSeed = avatarSeed
        self.profileImageURL = profileImageURL
    }
}

struct LilithSecureMessage: Codable, Hashable, Identifiable {
    let id: UUID
    var body: String
    var createdAt: Date
    var senderID: String
    var attachmentName: String?
    var attachmentData: Data?
}

struct LilithSecureThread: Codable, Hashable, Identifiable {
    let id: UUID
    var title: String
    var handle: String
    var lastMessagePreview: String
    var lastMessageAt: Date
    var unreadCount: Int
    var presence: ThreadPresence
    var isPinned: Bool
    var isMuted: Bool
    var isArchived: Bool
    var isGroup: Bool
    var topic: String?
    var members: [String]
    var messages: [LilithSecureMessage]
}

struct LilithCallSession: Codable, Hashable, Identifiable {
    let id: UUID
    var chatID: UUID
    var title: String
    var handle: String
    var type: LilithCallType
    var state: LilithCallState
    var startedAt: Date
    var muted: Bool
    var speakerOn: Bool
    var cameraOn: Bool
}

struct LilithCallRecord: Codable, Hashable, Identifiable {
    let id: UUID
    var peerName: String
    var peerHandle: String
    var type: LilithCallType
    var startedAt: Date
    var durationSeconds: Int
    var wasMissed: Bool
}

struct LilithSocialComment: Codable, Hashable, Identifiable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var body: String
    var createdAt: Date
}

struct LilithStory: Codable, Hashable, Identifiable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var caption: String
    var createdAt: Date
    var expiresAt: Date
}

struct LilithSocialPost: Codable, Hashable, Identifiable {
    let id: UUID
    var authorName: String
    var authorHandle: String
    var body: String
    var createdAt: Date
    var audience: LilithPostAudience
    var likeCount: Int
    var likedByMe: Bool
    var mediaLabel: String?
    var mediaData: Data?
    var tags: [String]
    var comments: [LilithSocialComment]
}

struct LilithDeviceSession: Codable, Hashable, Identifiable {
    let id: UUID
    var deviceName: String
    var lastSeenAt: Date
    var isCurrent: Bool
}

enum LilithBusinessCategory: String, Codable, Hashable {
    case professionalServices
    case creative
    case retail
}

struct LilithBusinessProfile: Codable, Hashable, Identifiable {
    let id: UUID
    var businessName: String
    var handle: String
    var tagline: String
    var category: LilithBusinessCategory
    var isVerified: Bool
    var acceptsPayments: Bool
    var responseTime: String
}

struct LilithBusinessService: Codable, Hashable, Identifiable {
    let id: UUID
    var businessID: UUID
    var name: String
    var description: String
}

struct LilithBusinessReview: Codable, Hashable, Identifiable {
    let id: UUID
    var businessID: UUID
    var rating: Int
    var body: String
    var createdAt: Date
}

struct LilithConnectionProfile: Codable, Hashable, Identifiable {
    let id: UUID
    var displayName: String
    var handle: String
    var profileImageURL: String?
    var bio: String
    var isConnected: Bool
}

struct LilithCommunicationSnapshot: Codable, Hashable {
    var profile: LilithIdentityProfile
    var threads: [LilithSecureThread]
    var stories: [LilithStory]
    var posts: [LilithSocialPost]
    var businessProfiles: [LilithBusinessProfile]
    var businessServices: [LilithBusinessService]
    var businessReviews: [LilithBusinessReview]
    var deviceSessions: [LilithDeviceSession]
}
