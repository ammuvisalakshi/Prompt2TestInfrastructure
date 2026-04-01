from diagrams import Diagram, Cluster, Edge
from diagrams.aws.devtools import Codepipeline, Codebuild
from diagrams.aws.management import Cloudwatch
from diagrams.aws.containers import ECR
from diagrams.aws.compute import Lambda, ECS
from diagrams.aws.storage import S3

with Diagram(
    "",
    show=False,
    filename="C:/MyProjects/AWS/Prompt2TestInfrastructure/diagrams/05_cicd_ops",
    direction="LR",
    outformat="png",
    graph_attr={
        "fontsize": "22",
        "bgcolor": "white",
        "fontcolor": "#232f3e",
        "pad": "1.0",
        "splines": "spline",
        "nodesep": "1.0",
        "ranksep": "2.5",
        "fontname": "Arial",
        "dpi": "150",
        "labelloc": "b",
        "label": "CI/CD & Operations",
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
    with Cluster("CI/CD Pipeline", graph_attr={"bgcolor": "#e6eef8", "pencolor": "#bdd0ea", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        pipeline = Codepipeline("CodePipeline")
        codebuild = Codebuild("CodeBuild")

    with Cluster("Container Registry", graph_attr={"bgcolor": "#f3eeff", "pencolor": "#b197fc", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        ecr = ECR("ECR\nplaywright-mcp\nbedrock-agent")

    with Cluster("Monitoring", graph_attr={"bgcolor": "#fef3e2", "pencolor": "#e8c877", "style": "rounded", "penwidth": "2", "fontsize": "14", "fontname": "Arial Bold", "fontcolor": "#232f3e"}):
        cw = Cloudwatch("CloudWatch\nLogs & Metrics")

    s3 = S3("S3\nReact SPA")
    lambda_fn = Lambda("Lambda")
    ecs = ECS("ECS Fargate")

    pipeline >> Edge(color="#232f3e", style="solid", label="triggers", fontsize="10", fontcolor="#545b64") >> codebuild
    codebuild >> Edge(color="#7048e8", style="solid", label="pushes image", fontsize="10", fontcolor="#545b64") >> ecr
    ecr >> Edge(color="#7048e8", style="dashed", label="pulls image", fontsize="10", fontcolor="#545b64") >> ecs
    pipeline >> Edge(color="#232f3e", style="dashed", label="deploys", fontsize="10", fontcolor="#545b64") >> s3
    pipeline >> Edge(color="#232f3e", style="dashed", label="deploys", fontsize="10", fontcolor="#545b64") >> lambda_fn
    lambda_fn >> Edge(color="#b45309", style="dotted", label="logs", fontsize="10", fontcolor="#545b64") >> cw
    ecs >> Edge(color="#b45309", style="dotted", label="logs", fontsize="10", fontcolor="#545b64") >> cw
