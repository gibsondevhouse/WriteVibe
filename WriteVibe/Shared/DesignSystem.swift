//
//  DesignSystem.swift
//  WriteVibe
//
//  Global design tokens, ViewModifiers, and Font scale.
//  This is the foundation layer — import nothing from Features.
//

import SwiftUI

// MARK: - Spacing

/// Semantic spacing scale (points). Always use WVSpace.* instead of magic numbers.
enum WVSpace {
    /// 4pt — icon-to-label gap, tightest padding
    static let xs:   CGFloat = 4
    /// 8pt — standard internal component padding
    static let sm:   CGFloat = 8
    /// 12pt — component internal horizontal padding
    static let md:   CGFloat = 12
    /// 14pt — card content padding (standard)
    static let base: CGFloat = 14
    /// 18pt — panel / large card content padding
    static let lg:   CGFloat = 18
    /// 20pt — topBar horizontal padding
    static let xl:   CGFloat = 20
    /// 24pt — section / canvas horizontal padding
    static let xxl:  CGFloat = 24
}

// MARK: - Corner Radius

/// Consistent corner radius scale.
enum WVRadius {
    /// 7pt — toggle chips (LengthChip)
    static let chip:   CGFloat = 7
    /// 8pt — stat pills, workspace chips
    static let chipLg: CGFloat = 8
    /// 10pt — standard cards (ArticleCard, draft items)
    static let card:   CGFloat = 10
    /// 12pt — large cards (hero cards, WorkspaceCard)
    static let cardLg: CGFloat = 12
    /// 14pt — panels (studioHero, large drawers)
    static let panel:  CGFloat = 14
    /// 16pt — input bar
    static let input:  CGFloat = 16
}

// MARK: - Animations

/// Standard animation presets. Always use WVAnim.* to keep motion consistent.
enum WVAnim {
    /// Standard panel / sidebar spring (response 0.25, damping 0.85)
    static let spring     = Animation.spring(response: 0.25, dampingFraction: 0.85)
    /// Fast dismissal spring (response 0.2, damping 0.9)
    static let springFast = Animation.spring(response: 0.2,  dampingFraction: 0.9)
    /// Hover card micro-animation (ease 0.15s)
    static let card       = Animation.easeInOut(duration: 0.15)
    /// Fade / opacity transitions (ease 0.2s)
    static let fade       = Animation.easeInOut(duration: 0.2)
}

// MARK: - Font Scale

extension Font {
    /// 28pt bold — workspace hero / large canvas titles
    static let wvHeroTitle = Font.system(size: 28, weight: .bold)
    /// 22pt bold — dashboard section identity headers
    static let wvTitle     = Font.system(size: 22, weight: .bold)
    /// 18pt bold — hero card section names
    static let wvHeadline  = Font.system(size: 18, weight: .bold)
    /// 15pt semibold — card titles, article list titles
    static let wvSubhead      = Font.system(size: 15, weight: .semibold)
    /// 13pt semibold — section headings, action button labels, prominent UI text
    static let wvActionLabel  = Font.system(size: 13, weight: .semibold)
    /// 13pt regular — body copy
    static let wvBody         = Font.system(size: 13)
    /// 12pt regular — secondary body / footnote
    static let wvFootnote  = Font.system(size: 12)
    /// 11pt medium — chip labels, UI labels
    static let wvLabel     = Font.system(size: 11, weight: .medium)
    /// 10pt semibold — section eyebrows, badge text
    static let wvMicro     = Font.system(size: 10, weight: .semibold)
    /// 9pt regular — very small supplemental labels
    static let wvNano      = Font.system(size: 9)
}

// MARK: - Card Modifier

/// Standard card surface: rounded rect + `.background` fill + subtle border + drop shadow.
/// Use `.wvCard()`, `.wvCardLg()`, or `.wvPanelCard()` on any view.
struct WVCardModifier: ViewModifier {
    var radius:        CGFloat = WVRadius.card
    var shadowRadius:  CGFloat = 6
    var shadowOpacity: Double  = 0.06

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.background)
                    .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            )
    }
}

extension View {
    /// Standard card — r=10, shadow 6pt / 6% opacity
    func wvCard() -> some View {
        modifier(WVCardModifier())
    }

    /// Large card — r=12, shadow 8pt / 8% opacity (hero cards, WorkspaceCard)
    func wvCardLg() -> some View {
        modifier(WVCardModifier(radius: WVRadius.cardLg, shadowRadius: 8, shadowOpacity: 0.08))
    }

    /// Panel card — r=14, shadow 8pt / 5% opacity (studioHero, drawer panels)
    func wvPanelCard() -> some View {
        modifier(WVCardModifier(radius: WVRadius.panel, shadowRadius: 8, shadowOpacity: 0.05))
    }
}

// MARK: - Section Label Modifier

/// Standard section eyebrow: small + semibold + uppercase + secondary + tracked.
/// Apply `.wvSectionLabel()` to any Text view.
struct WVSectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.wvMicro)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.9)
    }
}

extension View {
    func wvSectionLabel() -> some View {
        modifier(WVSectionLabelModifier())
    }
}
