import UIKit

enum ZixyImageLibrary {

    static let userAvatar = UIImage(named: "zixy_user_avatar")
    static let pageBackground = UIImage(named: "zixy_page_background")
    static let logo = UIImage(named: "zixy_logo")
    static let eulaPanel = UIImage(named: "zixy_eula_panel")
    static let eulaCancelButton = UIImage(named: "zixy_eula_cancel_button")
    static let eulaAgreeButton = UIImage(named: "zixy_eula_agree_button")
    static let profileHeader = UIImage(named: "zixy_profile_header")
    static let profileCamera = UIImage(named: "zixy_profile_camera")
    static let genderFemale = UIImage(named: "zixy_gender_female")
    static let genderMale = UIImage(named: "zixy_gender_male")
    static let authBackButton = UIImage(named: "zixy_auth_back_button")
    static let authPrimaryButton = UIImage(named: "zixy_auth_primary_button")
    static let authEmailIcon = UIImage(named: "zixy_auth_email_icon")
    static let authPasswordIcon = UIImage(named: "zixy_auth_password_icon")
    static let authVisibilityIcon = UIImage(named: "zixy_auth_visibility_icon")
    static let loginLogo = UIImage(named: "zixy_login_logo")
    static let loginWelcome = UIImage(named: "zixy_login_welcome")
    static let loginCardSignIn = UIImage(named: "zixy_login_card_sign_in")
    static let loginCardSignUp = UIImage(named: "zixy_login_card_sign_up")
    static let authEntryBackground = UIImage(named: "zixy_auth_entry_background")
    static let homeCategoryIndicator = UIImage(
        named: "zixy_home_category_indicator"
    )
    static let homeAIBanner = UIImage(named: "zixy_home_ai_banner")
    static let homeRoomPortrait = UIImage(named: "zixy_home_room_portrait")
    static let homeRoomOverlay = UIImage(named: "zixy_home_room_overlay")
    static let messagesTitle = UIImage(named: "zixy_messages_title")
    static let messagesNotifications = UIImage(
        named: "zixy_messages_notifications"
    )
    static let messagesAI = UIImage(named: "zixy_messages_ai")
    static let profileAvatar = UIImage(named: "zixy_profile_avatar")
    static let profileDisclosure = UIImage(named: "zixy_profile_disclosure")
    static let profileEdit = UIImage(named: "zixy_profile_edit")
    static let profileRoom = UIImage(named: "zixy_profile_room")
    static let profileBlacklist = UIImage(named: "zixy_profile_blacklist")
    static let profileSettings = UIImage(named: "zixy_profile_settings")
    static let followersAdd = UIImage(named: "zixy_followers_add")
    static let profileRemove = UIImage(named: "zixy_profile_remove")
    static let aiChatBackground = UIImage(named: "zixy_ai_chat_background")
    static let aiChatBackButton = UIImage(named: "zixy_ai_chat_back_button")
    static let aiChatSendIcon = UIImage(named: "zixy_ai_chat_send_icon")
    static let chatParticipantAvatar = UIImage(
        named: "zixy_chat_participant_avatar"
    )
    static let chatMoreIcon = UIImage(named: "zixy_chat_more_icon")
    static let chatSendIcon = UIImage(named: "zixy_chat_send_icon")
    static let alertPanelBackground = UIImage(
        named: "zixy_alert_panel_background"
    )
    static let termsCheckboxUnselected = UIImage(
        named: "zixy_terms_checkbox_unselected"
    )

    static func makePageBackgroundView() -> UIImageView {
        let imageView = UIImageView(image: pageBackground)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }
}
