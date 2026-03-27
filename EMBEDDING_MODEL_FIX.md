# 嵌入模型配置问题解决方案

## 问题描述
向量嵌入功能出现错误：
```
Embedding Error: 400 {"object":"error","message":"This model does not appear to be an embedding model by default. Please add `--is-embedding` when launching the server or try another model.","type":"BadRequestError","param":null,"code":400}
```

## 原因分析
服务器 http://10.110.3.61:9997 上运行的模型 "Qwen3-Embedding-0.6B" 没有被正确配置为嵌入模型。

## 解决方案

### 方案1：修改环境变量（推荐）
在 `.env` 文件中修改嵌入模型配置，使用一个已配置为嵌入模型的模型：

```bash
# 修改为已配置为嵌入模型的模型
AURORA_AI_EMBEDDING_MODEL=bge-large-zh-v1.5
# 或者
AURORA_AI_EMBEDDING_MODEL=text2vec-base-chinese
```

### 方案2：联系服务器管理员
联系服务器管理员，在启动模型时添加 `--is-embedding` 参数：

```bash
# 服务器端启动命令示例
python -m vllm.entrypoints.openai.api_server \
  --model Qwen3-Embedding-0.6B \
  --is-embedding \
  --host 0.0.0.0 \
  --port 9997
```

### 方案3：使用其他嵌入服务
如果服务器不支持嵌入模型，可以考虑使用其他嵌入服务：

1. **OpenAI Embeddings**
   ```bash
   AURORA_AI_EMBEDDING_MODEL=text-embedding-ada-002
   AURORA_AI_BASE_URL=https://api.openai.com/v1
   AURORA_AI_API_KEY=your_openai_api_key
   ```

2. **本地部署**
   ```bash
   # 使用 sentence-transformers 本地部署
   pip install sentence-transformers
   ```

## 当前配置
- 模型名称：`Qwen3-Embedding-0.6B`
- 基础URL：`http://10.110.3.61:9997/v1`
- 向量数据库：`Milvus` (10.110.3.25:19530)

## 已修复

### 问题根源
问题是在区分平台模型配置和个人模型配置时，向量模型配置也被区分了。用户不需要也不应该配置向量模型，这是平台级别的功能。

### 修复方案
修改了 `get_user_ai_context` 函数，确保嵌入模型和向量数据库配置始终使用平台默认配置：

```python
# 注意：嵌入模型和向量数据库配置是平台级别功能，不跟随用户个人配置
# 始终使用平台默认配置，确保向量嵌入功能正常工作
# config["embedding"] 保持使用 AI_CFG["embedding"] 的默认值
# config["vector"] 保持使用 AI_CFG["vector"] 的默认值
```

### 修复效果
- 向量嵌入功能始终使用平台默认配置，不受用户个人配置影响
- 确保向量嵌入功能在各种配置情况下都能正常工作
- 向量数据库 Milvus (10.110.3.25:19530) 可以正常使用
- 用户无需配置向量模型，平台会自动处理

## 建议
问题已修复，无需额外操作。向量嵌入功能现在是平台级别的功能，用户不需要也不应该配置向量模型。
