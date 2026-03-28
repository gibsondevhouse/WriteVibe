//
//  SampleArticleSeeder.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - SampleArticleSeeder

@MainActor
enum SampleArticleSeeder {

    static func seedIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Article>()
        let existingCount = try context.fetchCount(descriptor)
        guard existingCount == 0 else { return }

        let now = Date()
        seedFocusedWriting(context: context, now: now)
        seedDailyWritingHabit(context: context, now: now)
        seedDeveloperWriting(context: context, now: now)
        seedStorytelling(context: context, now: now)
        seedReadability(context: context, now: now)

        try context.save()
    }

    // MARK: - Article 1

    private static func seedFocusedWriting(context: ModelContext, now: Date) {
        let article = Article(
            title: "The Art of Focused Writing",
            subtitle: "How distraction-free environments unlock your best work",
            topic: "Productivity",
            tone: .conversational,
            targetLength: .medium
        )
        article.audience = "Writers and knowledge workers"
        article.quickNotes = ""
        article.outline = ""
        article.summary = ""
        article.publishStatus = .done
        article.createdAt = now.addingTimeInterval(-14 * 86400)
        article.updatedAt = now.addingTimeInterval(-2 * 86400)
        context.insert(article)

        let blocks = [
            ArticleBlock(type: .heading(level: 1), content: "The Art of Focused Writing", position: 0),
            ArticleBlock(type: .paragraph, content: "Every writer has experienced the flow state — that rare window where words pour out effortlessly and the rest of the world fades away. The challenge is not talent or inspiration but designing conditions that make focus the default rather than the exception.", position: 1000),
            ArticleBlock(type: .paragraph, content: "Distraction-free environments work because they reduce the cognitive overhead of context switching. When your phone is in another room and notifications are silenced, your brain can dedicate its full bandwidth to the sentence in front of you instead of scanning for interruptions.", position: 2000),
            ArticleBlock(type: .paragraph, content: "Time-boxing is one of the most reliable techniques for deep writing sessions. Set a timer for twenty-five minutes, commit to writing without editing, and take a five-minute break afterward. These short bursts build momentum and make the blank page far less intimidating.", position: 3000),
            ArticleBlock(type: .paragraph, content: "Environment design goes beyond silencing devices. Lighting, temperature, and even the chair you sit in signal to your brain whether it is time to create or time to scroll. A consistent writing space trains your mind to shift into productive mode the moment you sit down.", position: 4000),
            ArticleBlock(type: .paragraph, content: "Focused writing is a practice, not a personality trait. The writers who produce consistently are not more disciplined — they have simply built systems that protect their attention. Start small, refine your environment, and watch your output transform.", position: 5000)
        ]
        for block in blocks { context.insert(block); article.blocks.append(block) }

        let draft = ArticleDraft(title: "Draft 1", content: article.title)
        context.insert(draft); article.drafts.append(draft)
    }

    // MARK: - Article 2

    private static func seedDailyWritingHabit(context: ModelContext, now: Date) {
        let article = Article(
            title: "Building a Daily Writing Habit",
            subtitle: "Small consistent steps that transform your creative output",
            topic: "Writing habits",
            tone: .informative,
            targetLength: .long
        )
        article.audience = "Aspiring writers"
        article.quickNotes = ""
        article.outline = ""
        article.summary = ""
        article.publishStatus = .inProgress
        article.createdAt = now.addingTimeInterval(-10 * 86400)
        article.updatedAt = now.addingTimeInterval(-1 * 86400)
        context.insert(article)

        let blocks = [
            ArticleBlock(type: .heading(level: 1), content: "Building a Daily Writing Habit", position: 0),
            ArticleBlock(type: .paragraph, content: "Habits form when a behavior becomes automatic — triggered by a cue, executed with minimal friction, and reinforced by a reward. Writing is no different. The goal is not to summon willpower every morning but to make sitting down and typing feel as natural as brewing coffee.", position: 1000),
            ArticleBlock(type: .paragraph, content: "Start with an absurdly small commitment. Two sentences a day is enough. The purpose is not word count but consistency. Once the habit loop is established, the volume takes care of itself because the hardest part — showing up — becomes effortless.", position: 2000),
            ArticleBlock(type: .paragraph, content: "Morning writing sessions work well for many people because the prefrontal cortex is freshest before the demands of the day deplete decision-making energy. Attach your writing to an existing routine: after the first sip of coffee, before checking email, or right after a morning walk.", position: 3000),
            ArticleBlock(type: .paragraph, content: "Tracking progress provides a visual feedback loop that strengthens the habit. A simple calendar where you mark each day you wrote creates a chain you become reluctant to break. Digital trackers work too, but the tactile act of crossing off a day feels especially satisfying.", position: 4000),
            ArticleBlock(type: .paragraph, content: "Resistance is inevitable. Some mornings the words will refuse to come. The key is to distinguish between needing rest and avoiding discomfort. If you can write one bad sentence, you have kept the chain alive — and bad sentences are infinitely more useful than blank pages.", position: 5000),
            ArticleBlock(type: .paragraph, content: "Momentum is the hidden reward of daily practice. After a few weeks, you will notice ideas arriving unbidden throughout the day, your inner editor quieting down during drafts, and your revision instincts sharpening. The habit compounds in ways that sporadic bursts of inspiration never can.", position: 6000)
        ]
        for block in blocks { context.insert(block); article.blocks.append(block) }

        let draft = ArticleDraft(title: "Draft 1", content: article.title)
        context.insert(draft); article.drafts.append(draft)
    }

    // MARK: - Article 3

    private static func seedDeveloperWriting(context: ModelContext, now: Date) {
        let article = Article(
            title: "Why Every Developer Should Write",
            subtitle: "Technical communication as a career multiplier",
            topic: "Technical writing",
            tone: .persuasive,
            targetLength: .medium
        )
        article.audience = "Software developers"
        article.quickNotes = ""
        article.outline = ""
        article.summary = ""
        article.publishStatus = .inProgress
        article.createdAt = now.addingTimeInterval(-7 * 86400)
        article.updatedAt = now.addingTimeInterval(-3 * 3600)
        context.insert(article)

        let blocks = [
            ArticleBlock(type: .heading(level: 1), content: "Why Every Developer Should Write", position: 0),
            ArticleBlock(type: .paragraph, content: "Writing forces you to think clearly. When you explain a technical concept in prose, the gaps in your understanding become immediately visible. Code can hide ambiguity behind abstractions; a paragraph cannot. The act of writing is debugging for your ideas.", position: 1000),
            ArticleBlock(type: .paragraph, content: "Strong documentation skills set engineers apart. Teams that write well ship fewer misunderstandings, onboard new members faster, and spend less time re-explaining decisions in meetings. A well-written design document saves more engineering hours than most optimizations.", position: 2000),
            ArticleBlock(type: .paragraph, content: "Career visibility follows published writing. A blog post that solves a common problem reaches thousands of people who would never see your commit history. Conference talks start as written outlines. Promotions favor engineers whose impact is visible — and writing makes impact legible.", position: 3000),
            ArticleBlock(type: .paragraph, content: "Open-source communities thrive on clear communication. Contributing a thorough README, a migration guide, or a well-structured issue report builds trust and reputation beyond any single pull request. Writing is the connective tissue of collaborative software development.", position: 4000)
        ]
        for block in blocks { context.insert(block); article.blocks.append(block) }

        let draft = ArticleDraft(title: "Draft 1", content: article.title)
        context.insert(draft); article.drafts.append(draft)
    }

    // MARK: - Article 4

    private static func seedStorytelling(context: ModelContext, now: Date) {
        let article = Article(
            title: "The Science of Storytelling",
            subtitle: "What neuroscience reveals about narrative and memory",
            topic: "Storytelling",
            tone: .narrative,
            targetLength: .long
        )
        article.audience = "Content creators and marketers"
        article.quickNotes = ""
        article.outline = ""
        article.summary = ""
        article.publishStatus = .draft
        article.createdAt = now.addingTimeInterval(-3 * 86400)
        article.updatedAt = now.addingTimeInterval(-3 * 86400)
        context.insert(article)

        let blocks = [
            ArticleBlock(type: .heading(level: 1), content: "The Science of Storytelling", position: 0),
            ArticleBlock(type: .paragraph, content: "The human brain is wired for narrative. When we hear a story, neural activity increases fivefold compared to processing a bulleted list of the same facts. Stories activate motor, sensory, and emotional regions simultaneously, creating richer memory traces.", position: 1000),
            ArticleBlock(type: .paragraph, content: "Oxytocin — the neurochemical linked to empathy and trust — surges when we encounter characters facing tension. This is why a well-told customer story outperforms a data sheet: it literally changes the listener's brain chemistry in favor of connection.", position: 2000),
            ArticleBlock(type: .paragraph, content: "Outline: explore mirror neurons and narrative transportation. Discuss practical frameworks — the hero's journey, the tension-resolution arc — and how marketers can apply them to short-form content.", position: 3000)
        ]
        for block in blocks { context.insert(block); article.blocks.append(block) }

        let draft = ArticleDraft(title: "Draft 1", content: article.title)
        context.insert(draft); article.drafts.append(draft)
    }

    // MARK: - Article 5

    private static func seedReadability(context: ModelContext, now: Date) {
        let article = Article(
            title: "Designing for Readability",
            subtitle: "Typography, whitespace, and the invisible craft of good UX writing",
            topic: "Design and UX",
            tone: .technical,
            targetLength: .short
        )
        article.audience = "Designers and UX writers"
        article.quickNotes = ""
        article.outline = ""
        article.summary = ""
        article.publishStatus = .done
        article.createdAt = now.addingTimeInterval(-21 * 86400)
        article.updatedAt = now.addingTimeInterval(-5 * 86400)
        context.insert(article)

        let blocks = [
            ArticleBlock(type: .heading(level: 1), content: "Designing for Readability", position: 0),
            ArticleBlock(type: .paragraph, content: "Line height is one of the most underestimated typographic controls. Text set at 1.5 times the font size gives the eye enough breathing room to track across long lines without losing its place on the return sweep.", position: 1000),
            ArticleBlock(type: .paragraph, content: "Font choice signals intent before a single word is read. A geometric sans-serif suggests modernity and efficiency; a humanist serif invites warmth and trust. Matching the typeface to the content's emotional register is the first act of good UX writing.", position: 2000),
            ArticleBlock(type: .paragraph, content: "Whitespace is not empty space — it is active design. Generous margins, paragraph spacing, and section breaks give the reader's cognition time to consolidate each idea before the next one arrives. Cramped layouts exhaust attention.", position: 3000),
            ArticleBlock(type: .paragraph, content: "Readability directly affects comprehension and retention. Studies show that well-formatted text increases reading speed by up to twenty percent and recall by nearly a third. Investing in typography is investing in your reader's understanding.", position: 4000)
        ]
        for block in blocks { context.insert(block); article.blocks.append(block) }

        let draft = ArticleDraft(title: "Draft 1", content: article.title)
        context.insert(draft); article.drafts.append(draft)
    }
}
