toMarkdown  = require 'to-markdown'
languageGuesswork = require './language-guesswork'

keepWhitespace = (node, mark, content) ->
  prevNode = node.previousSibling
  nextNode = node.nextSibling
  prevNodeText = prevNode?.textContent
  nextNodeText = nextNode?.textContent
  prefix = if prevNode and (not toMarkdown.isBlock prevNode) and (prevNodeText?.charAt(prevNodeText.length - 1) isnt ' ')  then " #{ mark }" else mark
  suffix = if nextNode and (not toMarkdown.isBlock nextNode) and (nextNodeText?.charAt(nextNodeText.length - 1) isnt ' ') then "#{ mark } " else mark
  return prefix + content + suffix

guessLanguage = (content, node) ->

  # 尝试通过 data-code-language 获取
  language = node.getAttribute 'data-code-language'
  return language if language

  # 尝试通过 class (highlight-source-<language>/language-<language>) 获取。
  Array.prototype.some.call node.classList, (className) ->
    match = className.match /highlight-source-(\w+)/
    match = className.match /language-(\w+)/ if match is null
    return false if not match
    language = match[1]
    return true
  return language if language

  return languageGuesswork content

closest = (el, parentNodeName) ->
  while el isnt null
    parent = el.parentNode
    return parent if parent isnt null and parent.nodeName is parentNodeName
    el = parent

  return null

options =
  gfm: true

  converters: [
    # 'pre' 作为代码块
    (
      filter: 'pre'
      replacement: (content, node) ->
        language = guessLanguage content, node
        """
        \n
        ```#{ language }
        #{ content }
        ```
        \n
        """
    )

    # <span>/<section>/<div>/<cite>/<time>/<header>/<footer> 保持内容原样
    (
      filter: ['span', 'section', 'div', 'cite', 'time', 'header', 'footer']
      replacement: (content, node) -> if this.isBlock node then "\n\n#{ content }\n\n" else content
    )

    # 包含在 <pre> 元素中的 <code> 保持内容原样
    (
      filter: (node) ->
        return false if node.tagName isnt 'CODE'
        (closest node, 'pre') isnt null
      replacement: (content) -> content
    )

    # 去除没有 textContext 的 <a> 元素
    (
      filter: (node) ->
        return false unless node.nodeName is 'A'
        return true if not node.textContent
      replacement: -> ''
    )

    # 列表项标记与内容之前只需要一个空格
    (
      filter: 'li',
      replacement:  (content, node) ->
        content = content.replace(/^\s+/, '').replace /\n/gm, '\n  '
        prefix = '* '
        parent = node.parentNode
        index = Array.prototype.indexOf.call(parent.children, node) + 1
        prefix = if /ol/i.test(parent.nodeName) then index + '. ' else '* '
        return prefix + content
    )

    # <hr> 为 ---
    (
      filter: 'hr'
      replacement: -> '\n\n---\n\n'
    )

    # <em>/<i> 为 _，如果当前行前面有内容，前置空格，后同理
    (
      filter: ['em', 'i']
      replacement: (content, node) -> keepWhitespace node, '_', content
    )

    # <strong>/<b> 为 _，如果当前行前面有内容，前置空格，后同理
    (
      filter: ['strong', 'b']
      replacement: (content, node) -> keepWhitespace node, '**', content
    )
  ]

module.exports = markdownfiy = (html) -> toMarkdown html, options