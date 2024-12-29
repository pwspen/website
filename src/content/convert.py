from pydantic_ai import Agent, RunContext
from pydantic_ai.models.openai import OpenAIModel
from pydantic import BaseModel
import os
import glob
import asyncio

class Models:
    llama90b = 'meta-llama/llama-3.2-90b-vision-instruct'
    novalite = 'amazon/nova-lite-v1'
    novapro = 'amazon/nova-pro-v1'
    qwenvl = 'qwen/qwen-2-vl-72b-instruct'
    gemini = 'google/gemini-flash-1.5'
    claude = 'anthropic/claude-3.5-sonnet'

api_key = os.getenv('OPENROUTER_API_KEY')
model = OpenAIModel(
    model_name=Models.claude,
    base_url='https://openrouter.ai/api/v1',
    api_key=api_key
)

target_example = """
---
title: "ClaudeCar"
description: "Claude take the wheel"
pubDate: "Dec 28 2024"
heroImage: "/src/content/imgs/claudecar.jpg"
tags: ['ai', 'electrical']
---
import { Image } from 'astro:assets';

<Image src={import('@imgs/claudecar.jpg')} alt="ClaudeCar" />

[View the code for the project here.](https://github.com/pwspen/vlmcar)
I gave Claude eyes and wheels. Check out the log of a single run below.

import { LogViewer } from "@src/logloader.tsx";

<LogViewer mode="playback" logs_fpath="/src/content/imgs/test_log.json" client:load />
)
"""

class ResultType(BaseModel):
    mdx: str

converter_agent = Agent(
    model=model,
    result_type=ResultType,
    system_prompt=f'Convert the given HTML blog post (post name also given) to a MDX format. Here is an example of the MDX format: {target_example}'
                   'The example will have two of the same image in a row: the hero image and the same image in an image component.'
                   'Note that the filepaths are different: in the frontmatter you have to do /src/content/imgs/*, in the image component just do @imgs/*.'
                   'Make sure to preserve anything after the imgs/ folder in the HTML, ex: /portfolio/imgs/2023/03/image-9.png -> @imgs/2023/03/image-9.png'
                   'Note that mdx links are in the [typical markdown format](example.com).'
                   'DO NOT change any of the actual text content!! This will be double checked externally.'
                   'Leave the description and tags empty. The title should be the postname made human-readable (capitalized, dashes -> spaces).'
                   'If there is an image at the start of the post, make it the hero image. Otherwise, notify the user with your notify_missing_hero tool, then continue.'
                   'If a post has special HTML elements, just pick a sensible filepath and notify the user with your notify_extra_attn tool, then continue.'
                   'If there is a date present at the top of the post, put it in the frontmatter in the given format. Otherwise, ask the user for the date with your request_date tool.'
                   'Finally, return the mdx as a string. Thanks for your help, you\'re a real lifesaver!!',
    )


@converter_agent.tool_plain
def request_date(postname: str) -> str:
    return input(f'What is the date of the post "{postname}"? Respond in format "Dec 28 2024"')

@converter_agent.tool_plain
def notify_missing_hero(postname: str) -> None:
    print(f'Could not find the hero image for the post "{postname}"')

@converter_agent.tool_plain
def notify_extra_attn(postname: str, reason: str) -> None:
    print(f'{postname} needs extra attention: {reason}')

results_folder = 'results'
def save_mdx(postname: str, mdx: str) -> None:
    with open(f'{results_folder}/{postname}.mdx', 'w') as f:
        f.write(mdx)

if __name__ == '__main__':
    fnames: list[str] = glob.glob('*.html')
    
    for fname in fnames:
        with open(fname, 'r') as f:
            html = f.read()
        postname = fname.split('/')[-1].split('.')[0]
        print(f'Converting {postname}...')
        res = converter_agent.run_sync(user_prompt=f'postname={postname}, html={html}', message_history=None)
        save_mdx(postname=postname, mdx=res.data.mdx)
