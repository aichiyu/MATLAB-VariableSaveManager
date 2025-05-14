# VariableSaveManager - MATLAB变量存储管理工具

## 项目简介
本工具是一个MATLAB类库，用于高效管理变量的持久化存储与加载。通过哈希校验避免重复存储、增量清理旧变量、支持多版本兼容等特性，提升变量管理的可靠性与效率。

## 核心功能
- **自动哈希校验**：仅当变量内容变化时执行实际存储，优化重复保存效率
- **增量存储管理**：自动清理不再需要存储的旧变量（移入系统回收站），针对需要反复保存工作区变量的场景（如长时间计算过程中的中间结果保存），当大部分变量未修改时，通过哈希校验避免重复存储，最高可达到120倍MATLAB原生`save()`函数的速度

## 性能测试
以下是基准测试数据（测试环境：Intel i7-12700K + 慢BIWIN SSD；数据集：4GiB 三维/二维矩阵数据）：

|         保存方式         | 数据大小 (GiB) |  保存新数据耗时 (s) |  重复保存相同数据耗时 (s) | 速度 (GiB/s) |
|--------------------------|----------------|---------------------|---------------------------|--------------|
|      MATLAB save()       | 2.15           | 168.8               | 168.8                     | 0.025        |
|        Manager_v2        | 2.15           | 169.2               | 1.4                       | 2.964        |
|      内存数据（参考）    | 4.15           | 0.8（复制）         | 0.8（复制）               | 5.188        |

## 安装配置
### 部署步骤
1. 克隆本仓库到本地：`git clone https://github.com/aichiyu/MATLAB-VariableSaveManager.git`
2. 在MATLAB中添加项目目录到搜索路径（主页→设置路径→添加并包含子文件夹）

## 使用示例
### 1. 创建管理对象
```matlab
% 使用默认存储路径（变量将保存在当前目录下的matlab_data）
obj = VariableSaveManager();

% 自定义存储路径（需避免包含[/\*:?"<>|]等非法字符）
obj = VariableSaveManager('custom_path');
```

### 2. 保存变量
```matlab
% 准备待保存的变量（支持多变量）
v1 = [1 2 3];
v2 = 'example';

% 打包并保存（结构体字段名为变量名）
obj.save_var(struct('var1', v1, 'var2', v2));
% Tips: 使用whos函数可以直接导出变量名及其内容
```

### 3. 加载变量
```matlab
% 加载所有已保存变量到工作区
obj.load_vars();
```

### 4. 查看状态
```matlab
% 获取当前保存的变量名列表
saved_vars = obj.varnames;
```

## 目录结构
```
├─ ...                     % MATLAB工作区内的其他文件
└─ matlab_data/            % 默认存储目录（自动创建）
   ├─ var1.mat             % 变量存储文件
   ├─ var2.mat
   └─ datainfo__.mat       % 元数据文件（记录变量名和哈希值）
```

## 许可证
本工具使用了xxHash哈希算法（ https://github.com/Cyan4973/xxHash ）实现高效的内容校验。
本项目采用GPL-3.0许可证，具体内容见`LICENSE`文件。

## 贡献与反馈
欢迎提交Issue报告问题或建议，PR请遵循：
1. 保持代码风格一致（参考现有注释规范）
2. 添加必要的测试用例
3. 更新README说明新功能

# VariableSaveManager - MATLAB Variable Storage Management Tool

## Project Introduction
This tool is a MATLAB class library designed for efficient management of variable persistent storage and loading. It enhances the reliability and efficiency of variable management through features such as hash verification to avoid redundant storage, incremental cleanup of old variables, and multi-version compatibility.

## Core Features
- **Automatic Hash Verification**: Performs actual storage only when variable content changes, optimizing the efficiency of repeated saves.
- **Incremental Storage Management**: Automatically cleans up old variables that are no longer needed (moves them to the system recycle bin). For scenarios requiring repeated saving of workspace variables (e.g., saving intermediate results during long computation processes), when most variables are unchanged, hash verification avoids redundant storage, achieving up to 120 times the speed of MATLAB's native `save()` function.

## Performance Test
Below are benchmark test data (Test environment: Intel i7-12700K + Slow BIWIN SSD; Dataset: 4GiB 2D and 3D Matrix data):

|         Saving Method         | Data Size (GiB) | Time to Save New Data (s) | Time to Re-save Same Data (s) | Speed (GiB/s) |
|-------------------------------|-----------------|---------------------------|-------------------------------|---------------|
|      MATLAB save()            | 2.15            | 168.8                     | 168.8                         | 0.025         |
|        Manager_v2             | 2.15            | 169.2                     | 1.4                           | 2.964         |
|      In-memory Data (Reference) | 4.15           | 0.8 (Copy)                | 0.8 (Copy)                    | 5.188         |

## Installation and Configuration
### Deployment Steps
1. Clone this repository locally: `git clone https://github.com/aichiyu/MATLAB-VariableSaveManager.git`
2. Add the project directory to the MATLAB search path (Home → Set Path → Add with Subfolders).

## Usage Examples
### 1. Create a Management Object
```matlab
% Use default storage path (variables will be saved in matlab_data under the current directory)
obj = VariableSaveManager();

% Custom storage path (avoid invalid characters such as [/*:?"<>|])
obj = VariableSaveManager('custom_path');
```

### 2. Save Variables
```matlab
% Prepare variables to be saved (supports multiple variables)
v1 = [1 2 3];
v2 = 'example';

% Package and save (structure field names are variable names)
obj.save_var(struct('var1', v1, 'var2', v2));
% Tips: Use the whos function to directly export variable names and contents
```

### 3. Load Variables
```matlab
% Load all saved variables into the workspace
obj.load_vars();
```

### 4. Check Status
```matlab
% Get the list of currently saved variable names
saved_vars = obj.varnames;
```

## Directory Structure
```
├─ ...                     % Other files in the MATLAB workspace
└─ matlab_data/            % Default storage directory (auto-created)
   ├─ var1.mat             % Variable storage file
   ├─ var2.mat
   └─ datainfo__.mat       % Metadata file (records variable names and hash values)
```

## License
This tool uses the xxHash algorithm (https://github.com/Cyan4973/xxHash) for efficient content verification.
This project is licensed under the GPL-3.0 License. For details, see the `LICENSE` file.

## Contribution and Feedback
Welcome to submit Issues to report problems or suggestions. For PRs, please follow:
1. Maintain consistent code style (refer to existing comment specifications).
2. Add necessary test cases.
3. Update the README to describe new features.
