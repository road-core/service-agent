"""Functions/Tools definition."""

from typing import Optional

from langchain.tools import tool


# Using dummy functions for experimentation
@tool
def get_pods(namespace: str) -> str:
    """Get pod names from specific namespace."""
    if namespace == "lightspeed":
        return f"{namespace}_pod1"
    return "I don't have information"


# @tool
# def get_pods_memory(namespace: str = None, pod: str = None) -> float:
#     """Get memory usage by namespace."""
#     if pod:
#         pass
#     elif namespace == "lightspeed":
#         pod = get_pods(namespace)
#     else:
#         return "I don't have information"
#     return 2 * len(pod)


@tool
def get_pods_memory(pod: Optional[str] = None) -> float:
    """Get memory usage by namespace."""
    if pod:
        return 2 * len(pod)
    return "I don't have information"


tools = [get_pods, get_pods_memory]
