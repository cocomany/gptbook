#!/bin/bash

set -x
# 导入其他脚本
source .functions.sh

echo "Let's begin"
# 输入目标
goal=`input_goal`

task_list_file="saved_task_list.txt"
subtask_list_file="saved_subtask_list.txt"
output_file="saved_output.md"
rm -rf $task_list_file && touch $task_list_file
rm -rf $subtask_list_file && touch $subtask_list_file
rm -rf $output_file && touch $output_file

# 构思任务列表，检查任务列表并确定后保存
construct_task_list "$goal"

# 读取并展示 $task_list_file 内容，询问是否继续或者重新生成一级大纲
cat "$task_list_file"
read -p "是否继续使用现有的任务列表？(y/n): " choice

while [ "$choice" = "n" ]; do
    # 重新生成一级大纲
    construct_task_list "$goal"
    
    cat "$task_list_file"
    read -p "是否继续使用现有的任务列表？你也可以手动修改后继续(y/n): " choice
done



# Read task_list_file and store contents in an array
mapfile -t task_list_array < "$task_list_file"
# Loop through the array and output each element
for task in "${task_list_array[@]}"; do
  echo `date +'%Y-%m-%d %H:%M:%S'` "正在执行任务：$task"

  # 构思二级任务列表，检查并保存
  #subtask_list=$(construct_subtask_list "$task") # 这里你需要自己实现construct_subtask_list函数
  subtaskcontent=$(construct_subtask_list "$task")
  echo "$subtaskcontent" 
  read -p "二级大纲是否合适(y/n): " choice

  while [ "$choice" = "n" ]; do
      # 重新生成二级大纲
      subtaskcontent=$(construct_subtask_list "$task")
      echo "$subtaskcontent" 
      read -p "二级大纲是否合适(y/n): " choice
  done

  echo "$subtaskcontent" >> $subtask_list_file
  echo `date +'%Y-%m-%d %H:%M:%S'` "二级大纲任务完成：$task"
  done


# 进入二级任务列表循环调用二级任务信息
mapfile -t subtask_list_array < "$subtask_list_file"
for subtask in "${subtask_list_array[@]}"; do
  echo `date +'%Y-%m-%d %H:%M:%S'` "正在执行二级任务：$subtask"
  # 执行任务，标记状态，保存结果
  execute_subtask "$subtask"
  # 汇总二级任务输出
  echo `date +'%Y-%m-%d %H:%M:%S'` "二级任务完成：$subtask"
done
