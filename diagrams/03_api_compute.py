from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import APIGateway
from diagrams.aws.compute import Lambda, ECS, Fargate
from diagrams.aws.ml import Bedrock
from diagrams.aws.database import Aurora

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/03_api_compute",
    direction="LR",
    outformat="png",
    graph_attr={
        "fontsize": "22",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "1.0",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "2.0",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "API & Compute Layer",
    },
    node_attr={
        "fontsize": "12",
        "fontcolor": "#232f3e",
        "fontname": "Arial",
        "width": "1.5",
        "height": "1.5",
    },
    edge_attr={
        "penwidth": "2.0",
        "color": "#545b64",
        "arrowsize": "1.0",
    },
):
    with Cluster("API Gateway", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        apigw_rest = APIGateway("REST API")
        apigw_ws = APIGateway("WebSocket API")

    with Cluster("Compute", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        lambda_fn = Lambda("p2t-testcase-fn\nPython 3.12")

    with Cluster("AI Agent", graph_attr={"bgcolor": "#f3eeff", "pencolor": "#b197fc", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        bedrock = Bedrock("Bedrock AgentCore\nClaude Sonnet 4.5\n(Strands SDK)")

    with Cluster("Browser Automation", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        ecs = ECS("Playwright MCP\nServer")
        fargate = Fargate("Fargate\nARM64 2vCPU/4GB")

    aurora = Aurora("Aurora\nPostgreSQL")

    apigw_rest >> Edge(color="#232f3e", style="solid", label="CRUD", fontsize="10", fontcolor="#545b64") >> lambda_fn
    apigw_ws >> Edge(color="#7048e8", style="solid", label="real-time stream", fontsize="10", fontcolor="#7048e8") >> bedrock
    bedrock >> Edge(color="#7048e8", style="dashed", label="browser automation", fontsize="10", fontcolor="#7048e8") >> ecs
    lambda_fn >> Edge(color="#16a34a", style="solid", label="test cases", fontsize="10", fontcolor="#545b64") >> aurora
    bedrock >> Edge(color="#16a34a", style="dashed", label="plans + results", fontsize="10", fontcolor="#545b64") >> aurora
