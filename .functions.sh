#!/bin/bash
export LANG="en_US.UTF-8"

source .env
# 这个函数用于调用OpenAI API, 接收USERPROMPT
function call_openai_api() {
  local USERPROMPT=$1
  if [ -z "$2" ]; then
    TEMPERATURE=0.7
  else
    TEMPERATURE=$2
  fi
  # Check if $1 is empty
  if [ -z "$USERPROMPT" ]; then
    echo " Please provide a value for USERPROMPT."
    return 1
  fi
  #读取.env文件里定义的变量

  SYSTEMPROMPT=你是一个可靠的AI助手，你的回复言简意赅，不说多余的废话。

  result=$(curl -s ${OPENAI_API_BASE}/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d @- <<EOF
{
   "model": "$OPENAI_API_MODEL",
   "messages": [{"role": "system", "content": "$SYSTEMPROMPT"},{"role": "user", "content": "$USERPROMPT"}],
   "temperature": $TEMPERATURE
}
EOF
)
    #添加出错处理，如果result中有“rate limited”字样，则完全退出程序。
    if echo "$result" | grep -q "error"; then
        echo "Error: $result"
        exit 1
    fi
    content=$(echo "$result" | grep -o '"content":"[^"]*' | cut -d'"' -f4)
    content=$(printf "%b\n" "$content")
    # Extract the content using jq
    #content=$(echo "$result" | jq -r '.choices[0].message.content')
    echo "$content"
}

# 这个函数用于获取用户的目标
function input_goal() {
# 如果saved_goal.txt存在，则读取它，问是否修改或继续
if [ -f "saved_goal.txt" ]; then
  goal=$(cat saved_goal.txt)
  echo "$goal"
  read -p "是否要修改目标？$goal (y/n): " choice
  
  if [ "$choice" = "y" ]; then
    read -p "请输入新的目标： " new_goal
    goal="$new_goal"
    echo "$goal" > saved_goal.txt
    echo "$goal"
  fi
else
  echo "请输入你的目标："
  read goal
  echo "$goal" > saved_goal.txt
  echo "$goal"
fi
}

function read_goal() {
  # Check if saved_goal.txt does not exist or is empty
  if [ ! -s "saved_goal.txt" ]; then
    echo "Error: saved_goal.txt does not exist or is empty."
    return 1
  fi
  goal=$(cat saved_goal.txt)
  echo $goal
}

# 这个函数用于构建任务列表
function construct_task_list() {
  local goal=$1
  PREPROMPT_CONSTRUCT_TASK_LIST="你是一个资深主编，请根据以下{{书籍主题}}，直接列出一级大纲, csv格式，不要标题行，分隔符为|，示例为: '书籍主题|1. 章节题目|章节主要内容'。其中章节主要内容要尽量全面。 书籍主题如下： \n"
  userprompt="$PREPROMPT_CONSTRUCT_TASK_LIST\n$goal"
  #echo $userprompt
  result=$(call_openai_api "$userprompt")
  echo "$result"
  echo "$result" | grep -v '^$' >> saved_task_list.txt
}

function construct_subtask_list() {
  local task=$1
  goal=$(cat saved_goal.txt)
  PREPROMPT_CONSTRUCT_SUBTASK_LIST="你是一个资深主编，最终目标是写一本书，主题是$goal。请根据以下{{书籍章节信息}}，请你构思这一章应该有的子章节（二级大纲）, 每行一个子章节和内容，其中子章节主要内容要尽可能全面。 输出csv格式，分隔符为|，示例为: '书籍主题|1. 章节题目|1.1 子章节题目|子章节主要内容'。 给你的书籍章节信息如下："
  userprompt="$PREPROMPT_CONSTRUCT_SUBTASK_LIST\n$task \n 再次强调，输出csv格式，不要标题行，分隔符为|"
  #echo $userprompt
  result=$(call_openai_api "$userprompt")
  echo "$result" | grep -v '^$'
}

 
#write a book
function execute_subtask() {
  local subtask=$1
  goal=$(cat saved_goal.txt)
  PREPROMPT_EXECUTE_SUBTASK="你是一个资深主编，最终目标是写一本书，主题是$goal。我已有章节和子章节信息，请根据以下书籍的子章节信息，书写此子章节的具体内容。输出风格：语言严谨，层次分明，通俗易懂，知识点密集。输出markdown格式，如果是第1个子章节，比如1.1，则在前面输出章节名，否则，直接从子章节开始输出，子章节如1.1定义为H2，也就是markdown里的##。 可适当添加示例，对比表格等，或者添加下一层章节，增加可读性。输出内容一定要全面，详细。本章节字数1000字以上。书籍的章节信息如下："
  userprompt="$PREPROMPT_EXECUTE_SUBTASK\n$subtask"
  #echo $userprompt
  result=$(call_openai_api "$userprompt" 0.7)
  length=${#result}
  echo "本节内容长度: $length"
  echo "$result" >> saved_output.md
}