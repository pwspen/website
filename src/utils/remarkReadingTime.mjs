import { toString } from 'mdast-util-to-string';


function getReadingTime(content) {
    // Average reading speed (words per minute)
    const WORDS_PER_MINUTE = 200;
    
    // Count words by splitting on whitespace and filtering out empty strings
    const wordCount = content
      .trim()
      .split(/\s+/)
      .filter(word => word.length > 0)
      .length;
    
    // Calculate reading time in minutes, rounded up
    const readingTime = Math.ceil(wordCount / WORDS_PER_MINUTE);
    
    return readingTime;
  }

export function remarkReadingTime() {
  return function (tree, { data }) {
    const textContent = toString(tree);
    const readingTime = getReadingTime(textContent);
    
    // Inject the reading time into the frontmatter data
    data.astro.frontmatter.readingTime = readingTime;
  };
}