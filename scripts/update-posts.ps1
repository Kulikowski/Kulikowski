param(
    [string]$FeedUrl = 'https://www.kulikowski.me/feed.xml',
    [string]$ReadmePath = (Join-Path $PSScriptRoot '../README.md')
)

$ErrorActionPreference = 'Stop'
[xml]$feed = (Invoke-WebRequest -Uri $FeedUrl -TimeoutSec 30).Content
$posts = @($feed.rss.channel.item | Select-Object -First 3)
if ($posts.Count -eq 0) { throw 'The feed contains no posts; preserving the README.' }

$lines = foreach ($post in $posts) {
    $title = ([string]$post.title).Trim() -replace '\s+', ' '
    $title = $title.Replace('\', '\\').Replace('[', '\[').Replace(']', '\]')
    $url = [uri]([string]$post.link)
    if ($url.Scheme -ne 'https' -or $url.Host -notin @('kulikowski.me', 'www.kulikowski.me')) {
        throw "Unexpected post URL: $url"
    }
    if (-not $title) { throw 'A post has no title; preserving the README.' }
    '- [{0}]({1})' -f $title, $url.AbsoluteUri.Replace('(', '%28').Replace(')', '%29')
}

$readme = [IO.File]::ReadAllText($ReadmePath)
$pattern = '(?s)<!-- BLOG-POSTS:START -->.*?<!-- BLOG-POSTS:END -->'
if ([regex]::Matches($readme, $pattern).Count -ne 1) {
    throw 'Expected exactly one latest-posts block; preserving the README.'
}
$block = "<!-- BLOG-POSTS:START -->`n" + ($lines -join "`n") + "`n<!-- BLOG-POSTS:END -->"
$updated = [regex]::Replace($readme, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $block })
if ($updated -ne $readme) {
    [IO.File]::WriteAllText($ReadmePath, $updated, [Text.UTF8Encoding]::new($false))
    Write-Output 'Updated latest writing.'
} else {
    Write-Output 'Latest writing is already current.'
}
