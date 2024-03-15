#!/bin/bash  

source config

[ $(id -u) -gt 0 ] && echo "请用root用户执行此脚本！" && exit 1

#切换到脚本所在路径
DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd);
cd ${DIR}

#创建日志目录
if [ ! -d "log" ]; then
    mkdir log
fi
k8sCheckLogs="log/k8sCheckLogs_`date +%Y%m%d`.log"
rm -f ${k8sCheckLogs}

#获取所有节点名称
nodeList=()
nodeList=`kubectl get node | grep -w "Ready" | awk '{print $1}'`

# 检查节点健康状态
function getK8sNodesHealthy(){
    echo -e "############################ 检查节点健康状态 #############################"
    nodes=$(kubectl get nodes -o=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')  
    for node in $nodes; do  
      echo "节点 $node 的状态："  
      kubectl get node ${node} -o=jsonpath='{.status.conditions[*].type}';echo "";kubectl get node ${node} -o=jsonpath='{.status.conditions[*].status}';echo ""
      echo ""
    done
}

#NetworkUnavailable：表示当前节点网络是否不可用
#MemoryPressure：表示当前节点的内存压力的高低
#DiskPressure：表示当前节点的磁盘压力高低
#PIDPressure：表示当前节点的进程是否存在压力
#Ready：表示当前节点的状态是否健康和能够准备接收新的 Pods 运行

# 检查事件
function getK8sGetEvents(){
    echo ""
    echo ""
    echo -e "############################ 检查事件 ####################################"
    kubectl get events --all-namespaces --sort-by='.metadata.creationTimestamp'
}

# 检查资源分配情况
function getK8sQuota(){
    echo ""
    echo ""
    echo -e "############################ 检查命名空间资源分配情况 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        kubectl describe resourcequotas -n ${nameSpace}
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
    echo ""
    echo ""
    echo -e "############################ 检查命名空间资源分配情况 -- 按pod列出 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        kubectl describe node $(echo ${nodeList[0]} | awk '{print $1}') | grep Namespace
        for i in ${nodeList[@]};do
            kubectl describe node $i | sed -n '/Non-terminated Pods:/,/Allocated resources:/p' | grep -Ev 'Allocated resources:' | grep -E $(kubectl get pod -n ${nameSpace} | awk '{print $1}' | sed '1d' | tr "\n" "|" | sed -E 's/\|$//g')
        done
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
    echo ""
    echo ""
    echo -e "############################ 检查节点资源分配情况 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        for i in ${nodeList[@]};do
            echo "$i 节点资源分配情况"
            kubectl describe node $i | sed -n '/Allocated resources:/,/Events:/p' | grep -Ev 'Allocated|Event|storage|Total'
            echo ""
        done
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
    echo ""
    echo ""
    echo -e "############################ 检查节点资源分配情况 -- 按pod列出 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        for i in ${nodeList[@]};do
            echo "$i 节点资源分配情况明细"
            kubectl describe node $i | sed -n '/Non-terminated Pods:/,/Allocated resources:/p' | grep -Ev 'Allocated resources:'
            echo ""
        done
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
}

# 检查资源使用情况
function getK8sTop(){
    echo ""
    echo ""
    echo -e "############################ 检查节点资源使用情况 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        kubectl top nodes
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
    echo ""
    echo ""
    echo -e "############################ 检查节点资源使用情况 --- 按pod列出 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        for i in ${nodeList[@]};do
            echo "$i 节点资源使用情况明细"
            kubectl top pod -A | head -1;kubectl top pod -A | grep -E $(kubectl get pod -A -o wide | grep $i | awk '{print $2}' | tr "\n" "|" | sed -E 's/\|$//g')
            echo ""
        done
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
    echo ""
    echo ""
    echo -e "############################ 检查命名空间资源使用情况 #########################"
    # 检查Metrics API是否可用
    if kubectl top nodes &> /dev/null; then
        kubectl top pod -n ${nameSpace} --sort-by=cpu
    else
        echo "Metrics API 不可用，请确保Metrics Server已正确安装和配置。"
    fi
}

function getK8sDeplaymentsStatus(){
    echo ""
    echo ""
    echo -e "############################ Deplayments检查 #############################"
    # 获取Deployments的状态信息
    deployment_status=$( kubectl get deployments.apps -A | awk 'NR>1 {split($3,a,"/");if(a[1] != a[2]){print $0} }')
    # 检查输出是否为空
    if [ -z "$deployment_status" ]; then
        echo "Deplayments 无异常资源"
    else
        kubectl get deployments.apps -A | awk '{split($3,a,"/");if(a[1] != a[2]){print $0} }'
    fi
}
 
function getK8sStatefulsetsStatus(){
    echo ""
    echo ""
    echo -e "############################ Statefulsets检查 ############################"
    # 获取Statefulsets的状态信息
    statefulsets_status=$(kubectl get statefulsets.apps -A | awk 'NR>1 {split($3,a,"/");if(a[1] != a[2]){print $0} }')
    # 检查输出是否为空
    if [ -z "$statefulsets_status" ]; then
        echo "Statefulsets 无异常资源"
    else
        kubectl get statefulsets.apps -A | awk '{split($3,a,"/");if(a[1] != a[2]){print $0} }'
    fi 
}
 
function getK8sDaemonsetsStatus(){
    echo ""
    echo ""
    echo -e "############################ Daemonsets检查 ##############################"
    # 获取Daemonsets的状态信息
    daemonsets_status=$(kubectl get daemonsets.apps -A | awk 'NR>1 {split($3,a);split($4,b);split($7,c); if(a[1] != b[1] || b[1] != c[1] || c[1] != a[1]){print $0}}')
    # 检查输出是否为空
    if [ -z "$daemonsets_status" ]; then
        echo "Daemonsets 无异常资源"
    else
        kubectl get daemonsets.apps -A | awk '{split($3,a);split($4,b);split($7,c); if(a[1] != b[1] || b[1] != c[1] || c[1] != a[1]){print $0}}'
    fi 
}

function getK8sPodsStatus(){
    echo ""
    echo ""
    echo -e "############################ PODS检查 --- 处于非Running状态的pod #############################"
    # 获取Pods的状态信息
    pods_status=$(kubectl get pods -A | grep -Ev 'Running|Completed' | awk 'NR>1')
    # 检查输出是否为空
    if [ -z "$pods_status" ]; then
        echo "Pods 无异常资源"
    else
        kubectl get pods -A -owide | grep -Ev 'Running|Completed'
    fi
 
    echo ""
    echo ""
    echo -e "############################ PODS检查 --- 处于Running状态container异常的pods ##################"
    # 获取Pods的状态信息
    pods_status=$(kubectl get pods -A | grep Running | awk '{split($3,a,"/");if(a[1] != a[2]){print $0} }')
    # 检查输出是否为空
    if [ -z "$pods_status" ]; then
        echo "Pods 无异常资源"
    else
        kubectl get pods -A -owide | grep Running | awk '{split($3,a,"/");if(a[1] != a[2]){print $0} }'
    fi
}

function check(){
    getK8sNodesHealthy
    getK8sGetEvents
    getK8sQuota
    getK8sTop
    getK8sDeplaymentsStatus
    getK8sStatefulsetsStatus
    getK8sDaemonsetsStatus
    getK8sPodsStatus
}

#执行检查并保存检查结果
echo "巡检中，请勿关闭窗口..."
check > ${k8sCheckLogs}
echo "检查结果已保存在 ${k8sCheckLogs}"
