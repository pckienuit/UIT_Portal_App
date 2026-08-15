package com.pckienuit.uitportal

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class PortalArticleUrlTest {
    @Test
    fun acceptsVerifiedPortalArticleSlugs() {
        assertTrue(isPortalArticleUrl("https://portal.uit.edu.vn/bai-viet/thong-bao-moi"))
        assertTrue(isPortalArticleUrl("https://portal.uit.edu.vn/bai-viet/IR3-2026"))
    }

    @Test
    fun rejectsNonArticleAndDecoratedUrls() {
        assertFalse(isPortalArticleUrl("http://portal.uit.edu.vn/bai-viet/test"))
        assertFalse(isPortalArticleUrl("https://evil.example/bai-viet/test"))
        assertFalse(isPortalArticleUrl("https://portal.uit.edu.vn/admin"))
        assertFalse(isPortalArticleUrl("https://portal.uit.edu.vn/bai-viet/../admin"))
        assertFalse(isPortalArticleUrl("https://portal.uit.edu.vn/bai-viet/test?next=evil"))
        assertFalse(isPortalArticleUrl("https://portal.uit.edu.vn/bai-viet/test#fragment"))
    }
}
