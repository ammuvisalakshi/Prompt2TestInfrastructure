from diagrams import Diagram, Cluster, Edge
from diagrams.aws.network import CloudFront
from diagrams.aws.security import Cognito
from diagrams.aws.compute import Lambda, ECS
from diagrams.aws.database import Aurora, Dynamodb
from diagrams.aws.ml import Bedrock
from diagrams.aws.general import Users
from diagrams.aws.storage import S3
from diagrams.aws.network import APIGateway

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/01_overview",
    direction="LR",
    outformat="png",
    graph_attr={
        "fontsize": "22",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "1.0",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "2.2",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "Prompt2Test Platform - High-Level Architecture",
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
    users = Users("QA Engineers")

    with Cluster("Frontend & Auth", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        cf = CloudFront("CloudFront")
        s3 = S3("React SPA")
        cognito = Cognito("Cognito")

    with Cluster("API Layer", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        apigw = APIGateway("API Gateway\nREST + WebSocket")

    with Cluster("Compute & AI", graph_attr={"bgcolor": "#f3eeff", "pencolor": "#b197fc", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        lambda_fn = Lambda("Lambda")
        bedrock = Bedrock("Bedrock\nAgentCore")
        ecs = ECS("ECS Fargate\nPlaywright")

    with Cluster("Data Stores", graph_attr={"bgcolor": "#eaf5ea", "pencolor": "#82b882", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        aurora = Aurora("Aurora\nPostgreSQL")
        dynamo = Dynamodb("DynamoDB")

    users >> Edge(color="#232f3e", penwidth="2.5", style="solid") >> cf
    cf >> Edge(color="#232f3e", style="solid") >> s3
    cf >> Edge(color="#545b64", style="dashed", label="auth", fontsize="10", fontcolor="#545b64") >> cognito
    cf >> Edge(color="#232f3e", style="solid") >> apigw
    apigw >> Edge(color="#232f3e", style="solid") >> lambda_fn
    apigw >> Edge(color="#7048e8", style="solid", label="stream", fontsize="10", fontcolor="#7048e8") >> bedrock
    bedrock >> Edge(color="#545b64", style="dashed", label="automates", fontsize="10", fontcolor="#545b64") >> ecs
    lambda_fn >> Edge(color="#16a34a", style="solid") >> aurora
    cognito >> Edge(color="#2563eb", style="solid", label="config", fontsize="10", fontcolor="#545b64") >> dynamo
    bedrock >> Edge(color="#16a34a", style="dashed") >> aurora
