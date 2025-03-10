import { defineCollection, z } from 'astro:content'

const blog = defineCollection({
    type: 'content',
    // Type-check frontmatter using a schema
    schema: ({ image }) => z.object({
        title: z.string(),
        description: z.string(),
        // Transform string to Date object
        pubDate: z.coerce.date(),
        updatedDate: z.coerce.date().optional(),
        heroImage: image().optional(),
        tags: z.array(z.string()).optional(),
        inGrid: z.boolean().optional().default(true),
        readingTime: z.number().optional(),
    }),
})


export const collections = { blog }

